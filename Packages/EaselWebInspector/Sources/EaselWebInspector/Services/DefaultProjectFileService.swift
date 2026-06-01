//
//  DefaultProjectFileService.swift
//  EaselWebInspector
//
//  Default implementation of ProjectFileProviding using FileManager.
//

import EaselKit
import Foundation

public actor DefaultProjectFileService: ProjectFileProviding {
  private static let skippedDirectories: Set<String> = [
    ".git", ".svn", ".build", "DerivedData", "node_modules",
    ".next", ".nuxt", "dist", "build", "coverage", ".cache",
  ]

  private static let maxIndexedFileSize: UInt64 = 1_000_000

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
    guard !extensions.isEmpty else { return [] }

    return await Task.detached(priority: .utility) {
      let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath()
      let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey]

      guard let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: Array(resourceKeys),
        options: [.skipsHiddenFiles]
      ) else {
        return []
      }

      var results: [String] = []
      while let fileURL = enumerator.nextObject() as? URL {
        let values = try? fileURL.resourceValues(forKeys: resourceKeys)
        let isDirectory = values?.isDirectory == true

        if isDirectory {
          if Self.skippedDirectories.contains(fileURL.lastPathComponent) {
            enumerator.skipDescendants()
          }
          continue
        }

        let ext = fileURL.pathExtension.lowercased()
        guard extensions.contains(ext) else { continue }

        if let fileSize = values?.fileSize, UInt64(fileSize) > Self.maxIndexedFileSize {
          continue
        }

        results.append(fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
      }

      return results.sorted()
    }.value
  }
}
