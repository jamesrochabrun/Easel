//
//  ShadowWorkspaceManager.swift
//  EaselChat
//
//  Creates and diffs shadow workspaces for background agent jobs: a copy of
//  the project under <project>/.easel/tweaks/<jobId>/shadow that the agent
//  mutates instead of the real tree. `.easel` is on the observers' ignore
//  list, so shadow writes never trigger preview reloads.
//

import EaselKit
import Foundation

// MARK: - ShadowWorkspace

public struct ShadowWorkspace: Sendable, Equatable {
  public let jobId: UUID
  public let projectPath: String
  /// Absolute path of the shadow copy the agent runs in.
  public let rootPath: String
  /// Relative path → SHA-256 at snapshot time; the drift baseline.
  public let manifest: [String: String]

  public init(jobId: UUID, projectPath: String, rootPath: String, manifest: [String: String]) {
    self.jobId = jobId
    self.projectPath = projectPath
    self.rootPath = rootPath
    self.manifest = manifest
  }
}

// MARK: - ShadowFileChange

public struct ShadowFileChange: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    case modified
    case created
    case deleted
  }

  public let relativePath: String
  public let kind: Kind

  public init(relativePath: String, kind: Kind) {
    self.relativePath = relativePath
    self.kind = kind
  }
}

// MARK: - ShadowWorkspacing

public protocol ShadowWorkspacing: Sendable {
  /// Copies the project into a fresh shadow and returns its hash manifest.
  func create(projectPath: String, jobId: UUID) async throws -> ShadowWorkspace
  /// Rehashes the shadow against the manifest: modified/created/deleted.
  func changedFiles(in workspace: ShadowWorkspace) async throws -> [ShadowFileChange]
  /// Removes one job's artifact directory (shadow + backup + manifest).
  func cleanup(projectPath: String, jobId: UUID) async
  /// Removes artifact directories left behind by dead jobs (crash, quit).
  func sweepStaleArtifacts(projectPath: String, keeping liveJobIds: Set<UUID>) async
}

// MARK: - ShadowWorkspaceManager

public actor ShadowWorkspaceManager: ShadowWorkspacing {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  public func create(projectPath: String, jobId: UUID) async throws -> ShadowWorkspace {
    let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath()
    let shadowURL = Self.shadowRootURL(projectPath: projectPath, jobId: jobId)

    if fileManager.fileExists(atPath: shadowURL.path) {
      try fileManager.removeItem(at: shadowURL)
    }
    try fileManager.createDirectory(at: shadowURL, withIntermediateDirectories: true)

    var manifest: [String: String] = [:]
    for relativePath in Self.scannableFiles(under: projectURL, fileManager: fileManager) {
      let sourceURL = projectURL.appendingPathComponent(relativePath)
      let destinationURL = shadowURL.appendingPathComponent(relativePath)
      try fileManager.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
      manifest[relativePath] = try FileContentHasher.sha256OfFile(at: destinationURL.path)
    }

    let workspace = ShadowWorkspace(
      jobId: jobId,
      projectPath: projectURL.path,
      rootPath: shadowURL.path,
      manifest: manifest
    )
    try persistManifest(manifest, jobId: jobId, projectPath: projectPath)
    return workspace
  }

  public func changedFiles(in workspace: ShadowWorkspace) async throws -> [ShadowFileChange] {
    let shadowURL = URL(fileURLWithPath: workspace.rootPath)
    var changes: [ShadowFileChange] = []
    var seen = Set<String>()

    for relativePath in Self.scannableFiles(under: shadowURL, fileManager: fileManager) {
      seen.insert(relativePath)
      let currentHash = try FileContentHasher.sha256OfFile(
        at: shadowURL.appendingPathComponent(relativePath).path
      )
      if let baseline = workspace.manifest[relativePath] {
        if baseline != currentHash {
          changes.append(ShadowFileChange(relativePath: relativePath, kind: .modified))
        }
      } else {
        changes.append(ShadowFileChange(relativePath: relativePath, kind: .created))
      }
    }

    for relativePath in workspace.manifest.keys where !seen.contains(relativePath) {
      changes.append(ShadowFileChange(relativePath: relativePath, kind: .deleted))
    }

    return changes.sorted { $0.relativePath < $1.relativePath }
  }

  public func cleanup(projectPath: String, jobId: UUID) async {
    let jobURL = Self.jobDirectoryURL(projectPath: projectPath, jobId: jobId)
    try? fileManager.removeItem(at: jobURL)
  }

  public func sweepStaleArtifacts(projectPath: String, keeping liveJobIds: Set<UUID>) async {
    let artifactsURL = Self.artifactsRootURL(projectPath: projectPath)
    guard let entries = try? fileManager.contentsOfDirectory(
      at: artifactsURL,
      includingPropertiesForKeys: nil
    ) else {
      return
    }

    for entry in entries {
      guard let jobId = UUID(uuidString: entry.lastPathComponent) else { continue }
      if !liveJobIds.contains(jobId) {
        try? fileManager.removeItem(at: entry)
      }
    }
  }

  // MARK: - Layout

  static func artifactsRootURL(projectPath: String) -> URL {
    URL(fileURLWithPath: projectPath)
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("tweaks", isDirectory: true)
  }

  static func jobDirectoryURL(projectPath: String, jobId: UUID) -> URL {
    artifactsRootURL(projectPath: projectPath)
      .appendingPathComponent(jobId.uuidString, isDirectory: true)
  }

  static func shadowRootURL(projectPath: String, jobId: UUID) -> URL {
    jobDirectoryURL(projectPath: projectPath, jobId: jobId)
      .appendingPathComponent("shadow", isDirectory: true)
  }

  static func backupRootURL(projectPath: String, jobId: UUID) -> URL {
    jobDirectoryURL(projectPath: projectPath, jobId: jobId)
      .appendingPathComponent("backup", isDirectory: true)
  }

  // MARK: - Scanning

  /// Relative paths of regular files under `rootURL`, using the same rules
  /// as the preview file-change observer (hidden files skipped, shared
  /// ignore list respected) so scan scope matches what observers watch.
  static func scannableFiles(under rootURL: URL, fileManager: FileManager) -> [String] {
    guard let enumerator = fileManager.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
      return []
    }

    var relativePaths: [String] = []
    let rootPath = rootURL.standardizedFileURL.path
    for case let fileURL as URL in enumerator {
      let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
      if isDirectory == true {
        if ProjectScanIgnoreList.directoryNames.contains(fileURL.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }
      let filePath = fileURL.standardizedFileURL.path
      guard filePath.hasPrefix(rootPath + "/") else { continue }
      relativePaths.append(String(filePath.dropFirst(rootPath.count + 1)))
    }
    return relativePaths.sorted()
  }

  private func persistManifest(_ manifest: [String: String], jobId: UUID, projectPath: String) throws {
    let manifestURL = Self.jobDirectoryURL(projectPath: projectPath, jobId: jobId)
      .appendingPathComponent("manifest.json")
    let data = try JSONEncoder().encode(manifest)
    try data.write(to: manifestURL, options: .atomic)
  }
}
