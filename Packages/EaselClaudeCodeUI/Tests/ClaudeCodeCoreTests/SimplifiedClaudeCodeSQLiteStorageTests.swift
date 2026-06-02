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
      isWorktree: false
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
      isWorktree: false
    )
    try await storage.updateSessionMessages(id: oldSessionID, messages: messages)

    try await storage.updateSessionId(oldId: oldSessionID, newId: newSessionID)

    let oldSession = try await storage.getSession(id: oldSessionID)
    let storedNewSession = try await storage.getSession(id: newSessionID)
    let newSession = try XCTUnwrap(storedNewSession)
    XCTAssertNil(oldSession)
    XCTAssertEqual(newSession.messages.map(\.id), messages.map(\.id))
    XCTAssertEqual(newSession.messages.map(\.content), ["first", "reply"])
  }
}
