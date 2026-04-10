//
//  ProjectFileProviding.swift
//  EaselKit
//

import Foundation

/// Abstracts file system access for reading, writing, and listing project files.
public protocol ProjectFileProviding: Sendable {
  func readFile(at path: String, projectPath: String) async throws -> String
  func writeFile(at path: String, content: String, projectPath: String) async throws
  func listTextFiles(in projectPath: String, extensions: Set<String>) async -> [String]
}
