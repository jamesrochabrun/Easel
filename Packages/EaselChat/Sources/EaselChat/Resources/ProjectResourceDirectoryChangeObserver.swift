//
//  ProjectResourceDirectoryChangeObserver.swift
//  EaselChat
//

import Foundation

actor ProjectResourceDirectoryChangeObserver {
  private let projectPath: String
  private let fileManager: FileManager
  private var previousSnapshot: ProjectResourceDirectorySnapshot?

  init(projectPath: String, fileManager: FileManager = .default) {
    self.projectPath = projectPath
    self.fileManager = fileManager
  }

  func hasChangedSinceLastSnapshot() -> Bool {
    let currentSnapshot = ProjectResourceDirectorySnapshot.snapshot(
      projectPath: projectPath,
      fileManager: fileManager
    )
    defer { previousSnapshot = currentSnapshot }

    guard let previousSnapshot else {
      return false
    }

    return currentSnapshot != previousSnapshot
  }
}

struct ProjectResourceDirectorySnapshot: Equatable {
  private static let skippedDirectoryNames: Set<String> = [
    ".git", ".svn", ".build", "DerivedData", "node_modules",
    ".next", ".nuxt", "dist", "build", "coverage", ".cache",
    ".easel"
  ]

  let files: [String: ProjectResourceFileSignature]

  static func snapshot(
    projectPath: String,
    fileManager: FileManager = .default
  ) -> ProjectResourceDirectorySnapshot {
    let projectURL = URL(fileURLWithPath: projectPath)
      .standardizedFileURL
      .resolvingSymlinksInPath()

    guard let enumerator = fileManager.enumerator(
      at: projectURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return ProjectResourceDirectorySnapshot(files: [:])
    }

    var files: [String: ProjectResourceFileSignature] = [:]
    while let fileURL = enumerator.nextObject() as? URL {
      let values = try? fileURL.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
      )
      if values?.isDirectory == true {
        if skippedDirectoryNames.contains(fileURL.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }

      files[relativePath(for: fileURL, relativeTo: projectURL)] = ProjectResourceFileSignature(
        modificationDate: values?.contentModificationDate,
        fileSize: values?.fileSize
      )
    }

    return ProjectResourceDirectorySnapshot(files: files)
  }

  private static func relativePath(for fileURL: URL, relativeTo rootURL: URL) -> String {
    let resolvedFilePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    let resolvedRootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
    let rootPrefix = resolvedRootPath + "/"

    guard resolvedFilePath.hasPrefix(rootPrefix) else {
      return fileURL.lastPathComponent
    }

    return String(resolvedFilePath.dropFirst(rootPrefix.count))
  }
}

struct ProjectResourceFileSignature: Equatable {
  let modificationDate: Date?
  let fileSize: Int?
}
