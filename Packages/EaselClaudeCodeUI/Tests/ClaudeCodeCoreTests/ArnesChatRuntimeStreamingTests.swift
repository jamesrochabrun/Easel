//
//  ArnesChatRuntimeStreamingTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class ArnesChatRuntimeStreamingTests: XCTestCase {
  @MainActor
  func testTextDeltasStreamIntoOneMessageAndSettleOnAssistantEvent() {
    let (runtime, store, _) = makeRuntime()
    let firstAssistantMessageID = UUID()
    let state = ArnesChatRuntime.StreamState(
      messageId: firstAssistantMessageID,
      firstMessageInSession: nil
    )

    runtime.process(line: #"{"type":"text_delta","session_id":"S","text":"Hello"}"#, state: state)
    runtime.process(line: #"{"type":"text_delta","session_id":"S","text":" world"}"#, state: state)
    runtime.process(line: #"{"type":"assistant","session_id":"S","text":"Hello world."}"#, state: state)

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertEqual(messages[0].id, firstAssistantMessageID)
    XCTAssertEqual(messages[0].content, "Hello world.")
    XCTAssertTrue(messages[0].isComplete)
  }

  @MainActor
  func testToolCallAndResultPairThroughSharedToolUseID() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(
      line: #"{"type":"tool_call","session_id":"S","name":"bash","arguments":{"command":"swift build"}}"#,
      state: state
    )
    runtime.process(
      line: #"{"type":"tool_result","session_id":"S","name":"bash","preview":"exit 0"}"#,
      state: state
    )

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.toolUse, .toolResult])
    XCTAssertEqual(messages[0].toolName, "Bash")
    XCTAssertTrue(messages[0].content.contains("swift build"))
    XCTAssertEqual(messages[1].toolName, "Bash")
    XCTAssertEqual(messages[1].content, "exit 0")
    XCTAssertNotNil(messages[0].toolUseID)
    XCTAssertEqual(messages[0].toolUseID, messages[1].toolUseID)
  }

  @MainActor
  func testAssistantMessagesDoNotConcatenateAcrossTools() {
    let (runtime, store, _) = makeRuntime()
    let firstAssistantMessageID = UUID()
    let state = ArnesChatRuntime.StreamState(
      messageId: firstAssistantMessageID,
      firstMessageInSession: nil
    )

    runtime.process(line: #"{"type":"assistant","session_id":"S","text":"Looking at the project."}"#, state: state)
    runtime.process(line: #"{"type":"tool_call","session_id":"S","name":"read_file","arguments":{"path":"main.swift"}}"#, state: state)
    runtime.process(line: #"{"type":"tool_result","session_id":"S","name":"read_file","preview":"let x = 1"}"#, state: state)
    runtime.process(line: #"{"type":"assistant","session_id":"S","text":"Done."}"#, state: state)

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.assistant, .toolUse, .toolResult, .assistant])
    XCTAssertEqual(messages[0].id, firstAssistantMessageID)
    XCTAssertEqual(messages[0].content, "Looking at the project.")
    XCTAssertEqual(messages[3].content, "Done.")
    XCTAssertNotEqual(messages[3].id, firstAssistantMessageID)
    XCTAssertEqual(messages[1].toolName, "Read")
  }

  @MainActor
  func testReasoningDeltasBecomeThinkingMessage() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(line: #"{"type":"reasoning_delta","session_id":"S","text":"Let me think"}"#, state: state)
    runtime.process(line: #"{"type":"reasoning_delta","session_id":"S","text":" about this."}"#, state: state)
    runtime.process(line: #"{"type":"assistant","session_id":"S","text":"Answer."}"#, state: state)

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.thinking, .assistant])
    XCTAssertEqual(messages[0].content, "Let me think about this.")
    XCTAssertTrue(messages[0].isComplete)
    XCTAssertEqual(messages[1].content, "Answer.")
  }

  @MainActor
  func testInitEventStartsSessionWithArnesProvider() {
    let (runtime, _, sessionManager) = makeRuntime()
    var changedSessionId: String?
    let runtimeWithCallback = ArnesChatRuntime(
      messageDisplay: MessageStore(),
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      onSessionChange: { changedSessionId = $0 }
    )
    _ = runtime

    let state = ArnesChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: "Build a dashboard"
    )
    runtimeWithCallback.process(
      line: #"{"type":"init","session_id":"6BA7B810-9DAD-11D1-80B4-00C04FD430C8","model":"openrouter/auto","version":"0.7.0"}"#,
      state: state
    )

    XCTAssertEqual(sessionManager.currentSessionId, "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")
    XCTAssertEqual(changedSessionId, "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")
  }

  @MainActor
  func testResultEnvelopeRecordsUsageAndCost() throws {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    var recordedUsage: SessionUsageRecord?
    var recordedCost: Double?
    let runtime = ArnesChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "openrouter/auto",
      onSessionChange: nil,
      onUsageRecorded: { recordedUsage = $0 },
      onCostUpdate: { recordedCost = $0 }
    )
    let state = ArnesChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: "Build a dashboard",
      modelIdentifier: "openrouter/auto"
    )

    runtime.process(
      line: #"{"type":"result","session_id":"S","stop_reason":"completed","is_error":false,"result":"Done.","model":"openrouter/auto","routed_models":["anthropic/claude-sonnet-4.5"],"cost_usd":0.0421,"prompt_tokens":1200,"completion_tokens":300,"cached_tokens":800}"#,
      state: state
    )

    XCTAssertTrue(state.sawResult)
    let usage = try XCTUnwrap(recordedUsage)
    XCTAssertEqual(usage.provider, .arnes)
    XCTAssertEqual(usage.modelIdentifier, "anthropic/claude-sonnet-4.5")
    XCTAssertEqual(usage.inputTokens, 1_200)
    XCTAssertEqual(usage.outputTokens, 300)
    XCTAssertEqual(usage.cachedInputTokens, 800)
    XCTAssertEqual(recordedCost, 0.0421)
  }

  @MainActor
  func testErrorResultSurfacesErrorMessage() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(
      line: #"{"type":"result","session_id":"S","stop_reason":"error","is_error":true,"error":"rate limited (429) after 4 retries"}"#,
      state: state
    )

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages[0].isError)
    XCTAssertTrue(messages[0].content.contains("rate limited"))
  }

  @MainActor
  func testPlanUpdatedRendersChecklistCard() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(
      line: #"{"type":"tool_call","session_id":"S","name":"update_plan","arguments":{}}"#,
      state: state
    )
    runtime.process(
      line: #"{"type":"plan_updated","session_id":"S","steps":[{"step":"Read the code","status":"completed"},{"step":"Fix the bug","status":"in_progress"}]}"#,
      state: state
    )
    runtime.process(
      line: #"{"type":"tool_result","session_id":"S","name":"update_plan","preview":"plan recorded"}"#,
      state: state
    )

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.toolUse, .toolResult])
    XCTAssertEqual(messages[0].toolName, "TodoWrite")
    XCTAssertTrue(messages[0].content.contains("- [x] Read the code"))
    XCTAssertTrue(messages[0].content.contains("- [ ] Fix the bug"))
    XCTAssertEqual(messages[1].content, "Plan updated · 1/2 done")
  }

  @MainActor
  func testSubagentEventsRenderAsTaskCards() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(
      line: #"{"type":"subagent_started","session_id":"S","name":"explore","id":"a1b2c3d4","model":"deepseek/deepseek-v4-flash","task":"find the config loader"}"#,
      state: state
    )
    runtime.process(
      line: #"{"type":"subagent_finished","session_id":"S","name":"explore","id":"a1b2c3d4","steps":4,"tool_calls":7,"cost_usd":0.0012,"result_preview":"found it in Config.swift"}"#,
      state: state
    )

    let messages = store.getAllMessages()
    XCTAssertEqual(messages.map(\.role), [.toolUse, .toolResult])
    XCTAssertEqual(messages[0].toolName, "Task")
    XCTAssertTrue(messages[0].content.contains("find the config loader"))
    XCTAssertEqual(messages[0].toolUseID, "subagent-a1b2c3d4")
    XCTAssertEqual(messages[1].toolUseID, "subagent-a1b2c3d4")
    XCTAssertTrue(messages[1].content.contains("found it in Config.swift"))
  }

  @MainActor
  func testUnknownAndNonJSONLinesAreIgnored() {
    let (runtime, store, _) = makeRuntime()
    let state = ArnesChatRuntime.StreamState(messageId: UUID(), firstMessageInSession: nil)

    runtime.process(line: "not json at all", state: state)
    runtime.process(line: #"{"type":"retrying","session_id":"S","attempt":1,"reason":"rate limited (429)"}"#, state: state)
    runtime.process(line: #"{"type":"routed","session_id":"S","model":"x/y","provider":"openrouter"}"#, state: state)

    XCTAssertTrue(store.getAllMessages().isEmpty)
  }

  @MainActor
  func testModelResolutionReportsRoutedModelButNotAutoSlug() {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    var resolvedModels: [String] = []
    let runtime = ArnesChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "openrouter/auto",
      onSessionChange: nil,
      onModelResolved: { resolvedModels.append($0) }
    )
    let state = ArnesChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: nil,
      modelIdentifier: "openrouter/auto"
    )

    // The init event echoes the auto slug — a routing request, not a resolution.
    runtime.process(
      line: #"{"type":"init","session_id":"S","model":"openrouter/auto","version":"0.7.0"}"#,
      state: state
    )
    XCTAssertTrue(resolvedModels.isEmpty)

    runtime.process(
      line: #"{"type":"result","session_id":"S","stop_reason":"completed","is_error":false,"result":"Done.","model":"openrouter/auto","routed_models":["anthropic/claude-sonnet-4.5"],"prompt_tokens":100,"completion_tokens":20}"#,
      state: state
    )
    XCTAssertEqual(resolvedModels, ["anthropic/claude-sonnet-4.5"])
  }

  @MainActor
  func testRoutedEventReportsModelLiveWithoutAddingMessages() {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    var resolvedModels: [String] = []
    let runtime = ArnesChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "openrouter/auto",
      onSessionChange: nil,
      onModelResolved: { resolvedModels.append($0) }
    )
    let state = ArnesChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: nil,
      modelIdentifier: "openrouter/auto"
    )

    runtime.process(
      line: #"{"type":"routed","session_id":"S","model":"anthropic/claude-sonnet-4.5","provider":"openrouter"}"#,
      state: state
    )

    XCTAssertEqual(resolvedModels, ["anthropic/claude-sonnet-4.5"])
    XCTAssertTrue(store.getAllMessages().isEmpty)
  }

  @MainActor
  func testModelResolutionReportsConcreteModelFromInitEvent() {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    var resolvedModels: [String] = []
    let runtime = ArnesChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "x-ai/grok-4",
      onSessionChange: nil,
      onModelResolved: { resolvedModels.append($0) }
    )
    let state = ArnesChatRuntime.StreamState(
      messageId: UUID(),
      firstMessageInSession: nil,
      modelIdentifier: "x-ai/grok-4"
    )

    runtime.process(
      line: #"{"type":"init","session_id":"S","model":"x-ai/grok-4","version":"0.7.0"}"#,
      state: state
    )
    XCTAssertEqual(resolvedModels, ["x-ai/grok-4"])
  }

  // MARK: - Helpers

  @MainActor
  private func makeRuntime() -> (ArnesChatRuntime, MessageStore, SessionManager) {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    let runtime = ArnesChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: "/tmp/easel",
      onSessionChange: nil
    )
    return (runtime, store, sessionManager)
  }
}
