//
//  AgentTranscriptStore.swift
//  ClaudeCodeUI
//

import AgentHarness
import Foundation

/// Persistence for API-shaped agent transcripts, keyed by session id.
///
/// `StoredSession` keeps the UI-shaped `ChatMessage` rows for display restore;
/// the transcript stored here is the model-context source of truth used to
/// resume a session against the provider. The SQLite implementation lands in
/// workstream G (`api_transcripts` table on the existing database).
public protocol AgentTranscriptStore: Sendable {
  func loadTranscript(sessionId: String) async throws -> AgentTranscript?
  func saveTranscript(_ transcript: AgentTranscript, sessionId: String) async throws
  func deleteTranscript(sessionId: String) async throws
}

/// Default no-op implementation for tests and non-persistent configurations.
public actor NoOpAgentTranscriptStore: AgentTranscriptStore {
  public init() {}

  public func loadTranscript(sessionId: String) async throws -> AgentTranscript? { nil }
  public func saveTranscript(_ transcript: AgentTranscript, sessionId: String) async throws {}
  public func deleteTranscript(sessionId: String) async throws {}
}
