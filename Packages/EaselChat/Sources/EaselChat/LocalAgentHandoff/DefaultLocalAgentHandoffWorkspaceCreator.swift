//
//  DefaultLocalAgentHandoffWorkspaceCreator.swift
//  EaselChat
//

import Foundation

public actor DefaultLocalAgentHandoffWorkspaceCreator: LocalAgentHandoffWorkspaceCreating {
  private let fileManager: FileManager

  public init(
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
  }

  public func createWorkspace(
    for context: LocalAgentHandoffContext,
    in parentDirectory: URL
  ) async throws -> String {
    let isAccessing = parentDirectory.startAccessingSecurityScopedResource()
    defer {
      if isAccessing {
        parentDirectory.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let rootDirectory = parentDirectory.standardizedFileURL.resolvingSymlinksInPath()
      try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
      let directoryURL = uniqueDirectoryURL(
        for: context.project?.name ?? "Untitled Project",
        in: rootDirectory
      )
      try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      return directoryURL.path
    } catch {
      throw LocalAgentHandoffError.projectDirectoryCreationFailed(error.localizedDescription)
    }
  }

  private func uniqueDirectoryURL(for name: String, in rootDirectory: URL) -> URL {
    let baseSlug = slug(for: name)
    var candidate = rootDirectory.appendingPathComponent(baseSlug, isDirectory: true)
    var suffix = 2

    while fileManager.fileExists(atPath: candidate.path) {
      candidate = rootDirectory.appendingPathComponent("\(baseSlug)-\(suffix)", isDirectory: true)
      suffix += 1
    }

    return candidate
  }

  private func slug(for name: String) -> String {
    let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let allowed = CharacterSet.alphanumerics
    var result = ""
    var previousWasSeparator = false

    for scalar in folded.unicodeScalars {
      if allowed.contains(scalar) {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if !previousWasSeparator {
        result.append("-")
        previousWasSeparator = true
      }
    }

    let trimmed = result
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      .lowercased()
    return trimmed.isEmpty ? "untitled-project" : trimmed
  }
}
