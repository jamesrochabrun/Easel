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
  let files: [String: ProjectResourceFileSignature]

  static func snapshot(
    projectPath: String,
    fileManager: FileManager = .default
  ) -> ProjectResourceDirectorySnapshot {
    let resourcesURL = URL(fileURLWithPath: projectPath)
      .standardizedFileURL
      .resolvingSymlinksInPath()
      .appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)

    guard let resourceURLs = try? fileManager.contentsOfDirectory(
      at: resourcesURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return ProjectResourceDirectorySnapshot(files: [:])
    }

    var files: [String: ProjectResourceFileSignature] = [:]
    for fileURL in resourceURLs {
      let values = try? fileURL.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
      )
      guard values?.isDirectory != true else { continue }

      files[fileURL.lastPathComponent] = ProjectResourceFileSignature(
        modificationDate: values?.contentModificationDate,
        fileSize: values?.fileSize
      )
    }

    return ProjectResourceDirectorySnapshot(files: files)
  }
}

struct ProjectResourceFileSignature: Equatable {
  let modificationDate: Date?
  let fileSize: Int?
}
