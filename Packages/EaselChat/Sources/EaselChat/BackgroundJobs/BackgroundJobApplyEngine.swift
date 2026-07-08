//
//  BackgroundJobApplyEngine.swift
//  EaselChat
//
//  Moves a finished job's output from its shadow workspace into the real
//  project tree: drift detection against the job-start manifest, backup +
//  atomic apply, undo, and post-apply drift for safe undo prompts.
//  Deletions the agent made are intentionally not applied (v1): rare for
//  tweaks, and skipping them avoids destructive surprises.
//

import EaselKit
import Foundation

// MARK: - AppliedFile

public struct AppliedFile: Sendable, Equatable {
  public let relativePath: String
  public let kind: ShadowFileChange.Kind
  /// Hash of the content written into the real tree.
  public let appliedHash: String
  /// False when the file didn't exist in the real tree before apply.
  public let hadBackup: Bool

  public init(relativePath: String, kind: ShadowFileChange.Kind, appliedHash: String, hadBackup: Bool) {
    self.relativePath = relativePath
    self.kind = kind
    self.appliedHash = appliedHash
    self.hadBackup = hadBackup
  }
}

// MARK: - AppliedJobRecord

public struct AppliedJobRecord: Sendable, Equatable {
  public let jobId: UUID
  public let projectPath: String
  public let backupRoot: String
  public let appliedFiles: [AppliedFile]

  public init(jobId: UUID, projectPath: String, backupRoot: String, appliedFiles: [AppliedFile]) {
    self.jobId = jobId
    self.projectPath = projectPath
    self.backupRoot = backupRoot
    self.appliedFiles = appliedFiles
  }
}

// MARK: - BackgroundJobApplying

public protocol BackgroundJobApplying: Sendable {
  /// Files among `changes` whose real-tree content no longer matches the
  /// job-start manifest (a created-by-job file that now exists counts).
  func driftedFiles(
    changes: [ShadowFileChange],
    manifest: [String: String],
    projectPath: String
  ) async -> [String]

  /// Backs up current real-tree versions, then writes the shadow content.
  func apply(changes: [ShadowFileChange], workspace: ShadowWorkspace) async throws -> AppliedJobRecord

  /// Restores backups; deletes files that had no pre-apply version.
  func undo(record: AppliedJobRecord) async throws

  /// Applied files whose real-tree content changed again after apply.
  func postApplyDrift(record: AppliedJobRecord) async -> [String]
}

// MARK: - BackgroundJobApplyEngine

public actor BackgroundJobApplyEngine: BackgroundJobApplying {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  public func driftedFiles(
    changes: [ShadowFileChange],
    manifest: [String: String],
    projectPath: String
  ) async -> [String] {
    let projectURL = URL(fileURLWithPath: projectPath)
    var drifted: [String] = []

    for change in changes where change.kind != .deleted {
      let realPath = projectURL.appendingPathComponent(change.relativePath).path
      let currentHash = try? FileContentHasher.sha256OfFile(at: realPath)

      switch change.kind {
      case .modified:
        // Baseline must still be intact; a missing file is drift too.
        if currentHash != manifest[change.relativePath] {
          drifted.append(change.relativePath)
        }
      case .created:
        // The job created this file; it must not exist in the real tree yet.
        if currentHash != nil {
          drifted.append(change.relativePath)
        }
      case .deleted:
        break
      }
    }

    return drifted.sorted()
  }

  public func apply(changes: [ShadowFileChange], workspace: ShadowWorkspace) async throws -> AppliedJobRecord {
    let projectURL = URL(fileURLWithPath: workspace.projectPath)
    let shadowURL = URL(fileURLWithPath: workspace.rootPath)
    let backupURL = ShadowWorkspaceManager.backupRootURL(
      projectPath: workspace.projectPath,
      jobId: workspace.jobId
    )

    var appliedFiles: [AppliedFile] = []
    for change in changes where change.kind != .deleted {
      let realURL = projectURL.appendingPathComponent(change.relativePath)

      var hadBackup = false
      if fileManager.fileExists(atPath: realURL.path) {
        let backupFileURL = backupURL.appendingPathComponent(change.relativePath)
        try fileManager.createDirectory(
          at: backupFileURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: backupFileURL.path) {
          try fileManager.removeItem(at: backupFileURL)
        }
        try fileManager.copyItem(at: realURL, to: backupFileURL)
        hadBackup = true
      }

      let content = try Data(contentsOf: shadowURL.appendingPathComponent(change.relativePath))
      try fileManager.createDirectory(
        at: realURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try content.write(to: realURL, options: .atomic)

      appliedFiles.append(
        AppliedFile(
          relativePath: change.relativePath,
          kind: change.kind,
          appliedHash: FileContentHasher.sha256(of: content),
          hadBackup: hadBackup
        )
      )
    }

    return AppliedJobRecord(
      jobId: workspace.jobId,
      projectPath: workspace.projectPath,
      backupRoot: backupURL.path,
      appliedFiles: appliedFiles
    )
  }

  public func undo(record: AppliedJobRecord) async throws {
    let projectURL = URL(fileURLWithPath: record.projectPath)
    let backupURL = URL(fileURLWithPath: record.backupRoot)

    for applied in record.appliedFiles {
      let realURL = projectURL.appendingPathComponent(applied.relativePath)
      if applied.hadBackup {
        let content = try Data(contentsOf: backupURL.appendingPathComponent(applied.relativePath))
        try content.write(to: realURL, options: .atomic)
      } else if fileManager.fileExists(atPath: realURL.path) {
        try fileManager.removeItem(at: realURL)
      }
    }
  }

  public func postApplyDrift(record: AppliedJobRecord) async -> [String] {
    let projectURL = URL(fileURLWithPath: record.projectPath)
    var drifted: [String] = []

    for applied in record.appliedFiles {
      let realPath = projectURL.appendingPathComponent(applied.relativePath).path
      let currentHash = try? FileContentHasher.sha256OfFile(at: realPath)
      if currentHash != applied.appliedHash {
        drifted.append(applied.relativePath)
      }
    }

    return drifted.sorted()
  }
}
