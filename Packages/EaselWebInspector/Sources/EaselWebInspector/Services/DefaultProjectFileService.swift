//
//  DefaultProjectFileService.swift
//  EaselWebInspector
//
//  Default implementation of ProjectFileProviding using FileManager.
//

import EaselKit
import Foundation

public actor DefaultProjectFileService: ProjectFileProviding {

  public init() {}

  public func readFile(at path: String, projectPath: String) async throws -> String {
    let url = URL(fileURLWithPath: path)
    return try String(contentsOf: url, encoding: .utf8)
  }

  public func writeFile(at path: String, content: String, projectPath: String) async throws {
    let url = URL(fileURLWithPath: path)
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  public func listTextFiles(in projectPath: String, extensions: Set<String>) async -> [String] {
    let rootURL = URL(fileURLWithPath: projectPath)
    guard let enumerator = FileManager.default.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var results: [String] = []
    for case let fileURL as URL in enumerator {
      // Skip common non-source directories
      if fileURL.lastPathComponent == "node_modules" ||
         fileURL.lastPathComponent == ".git" ||
         fileURL.lastPathComponent == "dist" ||
         fileURL.lastPathComponent == "build" ||
         fileURL.lastPathComponent == ".next" {
        enumerator.skipDescendants()
        continue
      }

      let ext = fileURL.pathExtension.lowercased()
      guard extensions.contains(ext) else { continue }

      let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
      guard resourceValues?.isRegularFile == true else { continue }

      results.append(fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    return results
  }
}
