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

  @MainActor
  func testTurnCompletedRecordsTokenUsage() throws {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    var recordedUsage: SessionUsageRecord?
    let runtime = CodexChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "gpt-5.5",
      onSessionChange: nil,
      onUsageRecorded: { record in
        recordedUsage = record
      }
    )
    let state = CodexChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: "Build a dashboard",
      modelIdentifier: "gpt-5.5"
    )

    runtime.process(try decodeEvent("""
      {"type":"turn.completed","usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":25}}
      """), state: state)

    let usage = try XCTUnwrap(recordedUsage)
    XCTAssertEqual(usage.provider, .codex)
    XCTAssertEqual(usage.modelIdentifier, "gpt-5.5")
    XCTAssertEqual(usage.inputTokens, 1_000)
    XCTAssertEqual(usage.cachedInputTokens, 200)
    XCTAssertEqual(usage.outputTokens, 100)
    XCTAssertEqual(usage.reasoningOutputTokens, 25)
  }

  private func decodeEvent(_ json: String) throws -> CodexJSONEvent {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    var event = try decoder.decode(CodexJSONEvent.self, from: Data(json.utf8))
    event.rawLine = json
    return event
  }
}
