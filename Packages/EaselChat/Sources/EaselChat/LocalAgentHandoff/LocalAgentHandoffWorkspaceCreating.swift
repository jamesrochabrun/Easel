//
//  LocalAgentHandoffWorkspaceCreating.swift
//  EaselChat
//

import Foundation

public protocol LocalAgentHandoffWorkspaceCreating: Sendable {
  func createWorkspace(for context: LocalAgentHandoffContext, in parentDirectory: URL) async throws -> String
}
