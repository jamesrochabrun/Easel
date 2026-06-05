//
//  CodexDebugModelsCommandRunning.swift
//  ClaudeCodeUI
//

import Foundation

protocol CodexDebugModelsCommandRunning: Sendable {
  func debugModelsJSON(homeDirectory: String) async throws -> Data
}
