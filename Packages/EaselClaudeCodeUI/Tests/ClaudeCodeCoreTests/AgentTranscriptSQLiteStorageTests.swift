import AgentHarness
import Foundation
import SQLite
import XCTest
@testable import ClaudeCodeCore

final class AgentTranscriptSQLiteStorageTests: XCTestCase {
  private var temporaryRoot: URL!

  override func setUpWithError() throws {
    temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("easel-agent-transcript-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryRoot {
      try? FileManager.default.removeItem(at: temporaryRoot)
    }
    temporaryRoot = nil
  }

  // MARK: - Save / Load

  func testSaveAndLoadTranscriptRoundTrip() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let transcript = makeSampleTranscript()

    try await storage.saveTranscript(transcript, sessionId: "session-1")

    let loaded = try await storage.loadTranscript(sessionId: "session-1")
    XCTAssertEqual(loaded, transcript)
  }

  func testSaveTranscriptOverwritesContentAndTimestamp() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let sessionID = "session-1"
    let firstTranscript = AgentTranscript(version: 1, messages: [.system("first")])
    let secondTranscript = AgentTranscript(version: 1, messages: [
      .system("first"),
      .user([.text("second")])
    ])

    try await storage.saveTranscript(firstTranscript, sessionId: sessionID)
    let firstTimestamp = try transcriptUpdatedAt(for: sessionID)

    try await Task.sleep(nanoseconds: 50_000_000)
    try await storage.saveTranscript(secondTranscript, sessionId: sessionID)
    let secondTimestamp = try transcriptUpdatedAt(for: sessionID)

    let loaded = try await storage.loadTranscript(sessionId: sessionID)
    XCTAssertEqual(loaded, secondTranscript)
    XCTAssertGreaterThan(secondTimestamp, firstTimestamp)
    XCTAssertEqual(try transcriptRowCount(), 1)
  }

  func testLoadTranscriptForUnknownSessionReturnsNil() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)

    let loaded = try await storage.loadTranscript(sessionId: "missing-session")
    XCTAssertNil(loaded)
  }

  func testLoadTranscriptWithCorruptRowReturnsNil() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let sessionID = "corrupt-session"

    // Touch the database so the table exists, then write raw garbage directly.
    _ = try await storage.loadTranscript(sessionId: sessionID)
    let connection = try Connection(databasePath)
    try connection.run(
      "INSERT OR REPLACE INTO api_transcripts (session_id, transcript_json, updated_at) VALUES (?, ?, ?)",
      sessionID, "not-json{{{", Date().timeIntervalSince1970
    )

    let loaded = try await storage.loadTranscript(sessionId: sessionID)
    XCTAssertNil(loaded)
  }

  // MARK: - Delete

  func testDeleteTranscriptRemovesRow() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    try await storage.saveTranscript(makeSampleTranscript(), sessionId: "session-1")

    try await storage.deleteTranscript(sessionId: "session-1")

    let loaded = try await storage.loadTranscript(sessionId: "session-1")
    XCTAssertNil(loaded)
  }

  func testDeleteSessionRemovesTranscript() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let sessionID = "session-1"

    try await storage.saveSession(
      id: sessionID,
      firstMessage: "first",
      workingDirectory: "/tmp/easel",
      branchName: nil,
      isWorktree: false,
      provider: .claude
    )
    try await storage.saveTranscript(makeSampleTranscript(), sessionId: sessionID)

    try await storage.deleteSession(id: sessionID)

    let loaded = try await storage.loadTranscript(sessionId: sessionID)
    XCTAssertNil(loaded)
    XCTAssertEqual(try transcriptRowCount(), 0)
  }

  func testDeleteAllSessionsRemovesTranscripts() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)

    for sessionID in ["session-1", "session-2"] {
      try await storage.saveSession(
        id: sessionID,
        firstMessage: "first",
        workingDirectory: "/tmp/easel",
        branchName: nil,
        isWorktree: false,
        provider: .claude
      )
      try await storage.saveTranscript(makeSampleTranscript(), sessionId: sessionID)
    }

    try await storage.deleteAllSessions()

    let firstLoaded = try await storage.loadTranscript(sessionId: "session-1")
    let secondLoaded = try await storage.loadTranscript(sessionId: "session-2")
    XCTAssertNil(firstLoaded)
    XCTAssertNil(secondLoaded)
    XCTAssertEqual(try transcriptRowCount(), 0)
  }

  // MARK: - Session id updates

  func testUpdateSessionIdRekeysTranscript() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let transcript = makeSampleTranscript()

    try await storage.saveSession(
      id: "old-session",
      firstMessage: "first",
      workingDirectory: "/tmp/easel",
      branchName: nil,
      isWorktree: false,
      provider: .claude
    )
    try await storage.saveTranscript(transcript, sessionId: "old-session")

    try await storage.updateSessionId(oldId: "old-session", newId: "new-session")

    let oldLoaded = try await storage.loadTranscript(sessionId: "old-session")
    let newLoaded = try await storage.loadTranscript(sessionId: "new-session")
    XCTAssertNil(oldLoaded)
    XCTAssertEqual(newLoaded, transcript)
    XCTAssertEqual(try transcriptRowCount(), 1)
  }

  // MARK: - Migration

  func testMigrationAddsTranscriptTableToExistingDatabase() async throws {
    let appDir = temporaryRoot.appendingPathComponent("ClaudeCodeUI", isDirectory: true)
    try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

    // Simulate a pre-V7 database file: schema version 6 without api_transcripts.
    do {
      let connection = try Connection(databasePath)
      try connection.execute("""
        CREATE TABLE sessions (
          id TEXT PRIMARY KEY NOT NULL,
          created_at TEXT NOT NULL,
          first_user_message TEXT NOT NULL,
          last_accessed_at TEXT NOT NULL,
          working_directory TEXT,
          branch_name TEXT,
          is_worktree INTEGER NOT NULL DEFAULT 0,
          provider TEXT NOT NULL DEFAULT 'codex',
          usage_input_tokens INTEGER NOT NULL DEFAULT 0,
          usage_output_tokens INTEGER NOT NULL DEFAULT 0,
          usage_cached_input_tokens INTEGER NOT NULL DEFAULT 0,
          usage_reasoning_output_tokens INTEGER NOT NULL DEFAULT 0
        )
      """)
      try connection.execute("PRAGMA user_version = 6")
      XCTAssertEqual(try tableCount(named: "api_transcripts", on: connection), 0)
    }

    // Reopen through the storage layer; migration V7 must create the table.
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let transcript = makeSampleTranscript()
    try await storage.saveTranscript(transcript, sessionId: "session-1")

    let loaded = try await storage.loadTranscript(sessionId: "session-1")
    XCTAssertEqual(loaded, transcript)

    let connection = try Connection(databasePath)
    XCTAssertEqual(try tableCount(named: "api_transcripts", on: connection), 1)
    let version = try connection.scalar("PRAGMA user_version") as? Int64
    XCTAssertEqual(version, 7)
  }

  // MARK: - Helpers

  private var databasePath: String {
    temporaryRoot
      .appendingPathComponent("ClaudeCodeUI", isDirectory: true)
      .appendingPathComponent("claude_code_sessions.sqlite")
      .path
  }

  private func makeSampleTranscript() -> AgentTranscript {
    AgentTranscript(
      version: 1,
      messages: [
        .system("You are a helpful coding agent."),
        .user([.text("List the files in the project")]),
        .assistant(
          text: "Let me list the files.",
          toolCalls: [AgentToolCall(id: "call_1", name: "list_files", arguments: "{\"path\":\".\"}")]
        ),
        .tool(callId: "call_1", name: "list_files", content: "main.swift\nREADME.md", isError: false),
        .assistant(text: "The project contains main.swift and README.md.", toolCalls: [])
      ]
    )
  }

  private func transcriptUpdatedAt(for sessionId: String) throws -> Double {
    let connection = try Connection(databasePath)
    let value = try connection.scalar(
      "SELECT updated_at FROM api_transcripts WHERE session_id = ?", sessionId
    ) as? Double
    return try XCTUnwrap(value)
  }

  private func transcriptRowCount() throws -> Int64 {
    let connection = try Connection(databasePath)
    let value = try connection.scalar("SELECT count(*) FROM api_transcripts") as? Int64
    return try XCTUnwrap(value)
  }

  private func tableCount(named name: String, on connection: Connection) throws -> Int64 {
    let value = try connection.scalar(
      "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = ?", name
    ) as? Int64
    return try XCTUnwrap(value)
  }
}
