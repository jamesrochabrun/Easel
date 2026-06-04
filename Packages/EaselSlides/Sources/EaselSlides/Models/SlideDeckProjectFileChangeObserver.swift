//
//  SlideDeckProjectFileChangeObserver.swift
//  EaselSlides
//

import Foundation

actor SlideDeckProjectFileChangeObserver {
  private let projectPath: String
  private let fileManager: FileManager
  private var previousSnapshot: SlideDeckProjectFileSnapshot?

  init(projectPath: String, fileManager: FileManager = .default) {
    self.projectPath = projectPath
    self.fileManager = fileManager
  }

  func hasChangedSinceLastSnapshot() -> Bool {
    let currentSnapshot = SlideDeckProjectFileSnapshot.snapshot(
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

struct SlideDeckProjectFileSnapshot: Equatable {
  let files: [String: SlideDeckProjectFileSignature]

  static func snapshot(
    projectPath: String,
    fileManager: FileManager = .default
  ) -> SlideDeckProjectFileSnapshot {
    let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath()
    guard let enumerator = fileManager.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
      return SlideDeckProjectFileSnapshot(files: [:])
    }

    var files: [String: SlideDeckProjectFileSignature] = [:]
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

      files[relativePath] = SlideDeckProjectFileSignature(
        modificationDate: values?.contentModificationDate,
        fileSize: values?.fileSize
      )
    }

    return SlideDeckProjectFileSnapshot(files: files)
  }

  private static let ignoredDirectoryNames: Set<String> = [
    ".git",
    ".svn",
    ".swiftpm",
    ".build",
    ".easel",
    ".cache",
    ".next",
    ".nuxt",
    ".turbo",
    ".vercel",
    "DerivedData",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "out",
  ]

  private static func relativePath(for fileURL: URL, rootURL: URL) -> String? {
    let filePath = fileURL.standardizedFileURL.path
    let rootPath = rootURL.path
    guard filePath.hasPrefix(rootPath + "/") else {
      return nil
    }
    return String(filePath.dropFirst(rootPath.count + 1))
  }
}

struct SlideDeckProjectFileSignature: Equatable {
  let modificationDate: Date?
  let fileSize: Int?
}
