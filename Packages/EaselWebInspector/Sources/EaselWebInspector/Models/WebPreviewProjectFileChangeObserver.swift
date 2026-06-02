//
//  WebPreviewProjectFileChangeObserver.swift
//  EaselWebInspector
//

import Foundation

actor WebPreviewProjectFileChangeObserver {
  private let projectPath: String
  private let fileManager: FileManager
  private var previousSnapshot: WebPreviewProjectFileSnapshot?

  init(projectPath: String, fileManager: FileManager = .default) {
    self.projectPath = projectPath
    self.fileManager = fileManager
  }

  func hasChangedSinceLastSnapshot() -> Bool {
    let currentSnapshot = WebPreviewProjectFileSnapshot.snapshot(
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

struct WebPreviewProjectFileSnapshot: Equatable {
  let files: [String: WebPreviewProjectFileSignature]

  static func snapshot(
    projectPath: String,
    fileManager: FileManager = .default
  ) -> WebPreviewProjectFileSnapshot {
    let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath()
    guard let enumerator = fileManager.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else {
      return WebPreviewProjectFileSnapshot(files: [:])
    }

    var files: [String: WebPreviewProjectFileSignature] = [:]
    for case let fileURL as URL in enumerator {
      let values = try? fileURL.resourceValues(
        forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
      )

      if values?.isDirectory == true {
        if ignoredDirectoryNames.contains(fileURL.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }

      guard let relativePath = relativePath(for: fileURL, rootURL: rootURL) else {
        continue
      }

      files[relativePath] = WebPreviewProjectFileSignature(
        modificationDate: values?.contentModificationDate,
        fileSize: values?.fileSize
      )
    }

    return WebPreviewProjectFileSnapshot(files: files)
  }

  private static let ignoredDirectoryNames: Set<String> = [
    ".git",
    ".swiftpm",
    ".build",
    ".easel",
    "node_modules",
  ]

  private static func relativePath(for fileURL: URL, rootURL: URL) -> String? {
    let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    let rootPath = rootURL.path
    guard filePath.hasPrefix(rootPath + "/") else {
      return nil
    }
    return String(filePath.dropFirst(rootPath.count + 1))
  }
}

struct WebPreviewProjectFileSignature: Equatable {
  let modificationDate: Date?
  let fileSize: Int?
}
