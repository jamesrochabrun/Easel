import Foundation
import XCTest
@testable import ClaudeCodeCore

final class SimplifiedClaudeCodeSQLiteStorageTests: XCTestCase {
  private var temporaryRoot: URL!

  override func setUpWithError() throws {
    temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("easel-sqlite-storage-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryRoot {
      try? FileManager.default.removeItem(at: temporaryRoot)
    }
    temporaryRoot = nil
  }

  func testUpdateSessionMessagesReplacesExistingRows() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let sessionID = "session-1"
    let messageID = UUID()

    try await storage.saveSession(
      id: sessionID,
      firstMessage: "first",
      workingDirectory: "/tmp/easel",
      branchName: nil,
      isWorktree: false,
      provider: .claude
    )

    try await storage.updateSessionMessages(id: sessionID, messages: [
      ChatMessage(id: messageID, role: .user, content: "first"),
      ChatMessage(role: .toolUse, content: "old assistant", messageType: .toolUse, toolUseID: "old-tool")
    ])

    try await storage.updateSessionMessages(id: sessionID, messages: [
      ChatMessage(id: messageID, role: .toolUse, content: "updated", messageType: .toolUse, toolUseID: "tool-1")
    ])

    let storedSession = try await storage.getSession(id: sessionID)
    let session = try XCTUnwrap(storedSession)
    XCTAssertEqual(session.messages.map(\.content), ["updated"])
    XCTAssertEqual(session.messages.map(\.toolUseID), ["tool-1"])
  }

  func testUpdateSessionIdMovesMessagesBeforeDeletingOldSession() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let oldSessionID = "old-session"
    let newSessionID = "new-session"
    let messages = [
      ChatMessage(
        id: UUID(),
        role: .user,
        content: "first",
        timestamp: Date(timeIntervalSince1970: 10)
      ),
      ChatMessage(
        id: UUID(),
        role: .assistant,
        content: "reply",
        timestamp: Date(timeIntervalSince1970: 11)
      )
    ]

    try await storage.saveSession(
      id: oldSessionID,
      firstMessage: "first",
      workingDirectory: "/tmp/easel",
      branchName: nil,
      isWorktree: false,
      provider: .claude
    )
    try await storage.updateSessionMessages(id: oldSessionID, messages: messages)

    try await storage.updateSessionId(oldId: oldSessionID, newId: newSessionID)

    let oldSession = try await storage.getSession(id: oldSessionID)
    let storedNewSession = try await storage.getSession(id: newSessionID)
    let newSession = try XCTUnwrap(storedNewSession)
    XCTAssertNil(oldSession)
    XCTAssertEqual(newSession.messages.map(\.id), messages.map(\.id))
    XCTAssertEqual(newSession.messages.map(\.content), ["first", "reply"])
    XCTAssertEqual(newSession.provider, .claude)
  }

  func testRecordUsagePersistsSessionAndWorkingDirectorySummaries() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)
    let workingDirectory = "/tmp/easel"

    try await storage.saveSession(
      id: "session-1",
      firstMessage: "first",
      workingDirectory: workingDirectory,
      branchName: nil,
      isWorktree: false,
      provider: .codex
    )
    try await storage.saveSession(
      id: "session-2",
      firstMessage: "second",
      workingDirectory: workingDirectory,
      branchName: nil,
      isWorktree: false,
      provider: .codex
    )

    try await storage.recordUsage(
      id: "session-1",
      usage: SessionUsageRecord(
        provider: .codex,
        modelIdentifier: "gpt-5.5",
        inputTokens: 1_000,
        outputTokens: 200,
        cachedInputTokens: 100,
        reasoningOutputTokens: 25
      )
    )
    try await storage.recordUsage(
      id: "session-2",
      usage: SessionUsageRecord(
        provider: .codex,
        modelIdentifier: "gpt-5.5",
        inputTokens: 500,
        outputTokens: 50
      )
    )

    let storedSession = try await storage.getSession(id: "session-1")
    let session = try XCTUnwrap(storedSession)
    XCTAssertEqual(session.usageSummary.inputTokens, 1_000)
    XCTAssertEqual(session.usageSummary.outputTokens, 200)
    XCTAssertEqual(session.usageSummary.cachedInputTokens, 100)
    XCTAssertEqual(session.usageSummary.reasoningOutputTokens, 25)

    let workspaceSummary = try await storage.usageSummaryForWorkingDirectory(workingDirectory)
    XCTAssertEqual(workspaceSummary.inputTokens, 1_500)
    XCTAssertEqual(workspaceSummary.outputTokens, 250)
    XCTAssertEqual(workspaceSummary.cachedInputTokens, 100)
    XCTAssertEqual(workspaceSummary.reasoningOutputTokens, 25)
  }

  func testSessionProviderPersists() async throws {
    let storage = SimplifiedClaudeCodeSQLiteStorage(applicationSupportDirectory: temporaryRoot)

    try await storage.saveSession(
      id: "claude-session",
      firstMessage: "first",
      workingDirectory: "/tmp/easel",
      branchName: nil,
      isWorktree: false,
      provider: .claude
    )

    let storedSession = try await storage.getSession(id: "claude-session")
    let session = try XCTUnwrap(storedSession)
    XCTAssertEqual(session.provider, .claude)
  }
}
