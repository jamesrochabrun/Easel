//
//  CodexChatRuntimeStreamingTests.swift
//  ClaudeCodeCoreTests
//

import CodexSDK
import XCTest
@testable import ClaudeCodeCore

final class CodexChatRuntimeStreamingTests: XCTestCase {
  @MainActor
  func testCompletedAgentMessagesDoNotConcatenateAcrossTools() throws {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    let runtime = CodexChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      onSessionChange: nil
    )
    let firstAssistantMessageID = UUID()
    let state = CodexChatRuntime.StreamState(
      messageId: firstAssistantMessageID,
      firstMessageInSession: nil
    )

    runtime.process(try decodeEvent("""
      {"type":"item.completed","item":{"id":"agent-1","type":"agent_message","text":"I will inspect the project first."}}
      """), state: state)
    runtime.process(try decodeEvent("""
      {"type":"item.started","item":{"id":"command-1","type":"command_execution","command":"ls"}}
      """), state: state)
    runtime.process(try decodeEvent("""
      {"type":"item.completed","item":{"id":"command-1","type":"command_execution","command":"ls","aggregatedOutput":"index.html\\n","exitCode":0}}
      """), state: state)
    runtime.process(try decodeEvent("""
      {"type":"item.completed","item":{"id":"agent-2","type":"agent_message","text":"The scaffold has a single HTML entry point."}}
      """), state: state)

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.assistant, .toolUse, .toolResult, .assistant])
    XCTAssertEqual(messages[0].id, firstAssistantMessageID)
    XCTAssertEqual(messages[0].content, "I will inspect the project first.")
    XCTAssertEqual(messages[3].content, "The scaffold has a single HTML entry point.")
    XCTAssertNotEqual(messages[3].id, firstAssistantMessageID)
    XCTAssertTrue(messages[0].isComplete)
    XCTAssertTrue(messages[3].isComplete)
  }

  private func decodeEvent(_ json: String) throws -> CodexJSONEvent {
    try JSONDecoder().decode(CodexJSONEvent.self, from: Data(json.utf8))
  }
}
