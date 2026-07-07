import XCTest
@testable import AgentHarness

final class AgentLoopTests: XCTestCase {

  private func makeLoop(
    scripts: [ScriptedTurn],
    tools: [any AgentTool] = [EchoTool()],
    capabilities: ModelCapabilities = ModelCapabilities(),
    configuration: AgentLoopConfiguration = AgentLoopConfiguration()
  ) -> (loop: AgentLoop, client: ScriptedModelClient) {
    let client = ScriptedModelClient(capabilities: capabilities, scripts: scripts)
    let loop = AgentLoop(
      client: client,
      tools: tools,
      configuration: configuration,
      context: makeToolContext()
    )
    return (loop, client)
  }

  private var seedTranscript: AgentTranscript {
    AgentTranscript(messages: [.system("You are a test agent."), .user([.text("do the thing")])])
  }

  // MARK: - Basic completion

  func testTextOnlyTurnCompletes() async {
    let (loop, client) = makeLoop(scripts: [
      .events([.textDelta("Hel"), .textDelta("lo"), .usage(AgentTokenUsage(inputTokens: 10, outputTokens: 2)), .finish(.stop)])
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)

    XCTAssertNil(error)
    XCTAssertEqual(client.requests.count, 1)

    let deltas = events.compactMap { if case .assistantTextDelta(let t) = $0 { return t } else { return nil } }
    XCTAssertEqual(deltas.joined(), "Hello")

    guard case .completed(let finalText)? = events.last else {
      return XCTFail("expected completed as last event, got \(String(describing: events.last))")
    }
    XCTAssertEqual(finalText, "Hello")

    let transcript = lastTranscript(in: events)!
    XCTAssertEqual(transcript.messages.last, .assistant(text: "Hello", toolCalls: []))
    assertTranscriptIsAPIValid(transcript)
  }

  // MARK: - Tool-call reassembly through the loop

  func testFragmentedToolCallExecutesAndFeedsResultToNextTurn() async {
    let arguments = #"{"value":"a \"quoted\" 🚀 string"}"#
    var fragments: [AgentModelEvent] = [.toolCallDelta(index: 0, id: "call_1", name: "Echo", argumentsFragment: "")]
    var remaining = Substring(arguments)
    while !remaining.isEmpty {
      fragments.append(.toolCallDelta(index: 0, id: nil, name: nil, argumentsFragment: String(remaining.prefix(4))))
      remaining = remaining.dropFirst(4)
    }
    fragments.append(.finish(.toolCalls))

    let (loop, client) = makeLoop(scripts: [
      .events(fragments),
      .events([.textDelta("done"), .finish(.stop)]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)
    XCTAssertEqual(client.requests.count, 2)

    let transcript = lastTranscript(in: events)!
    assertTranscriptIsAPIValid(transcript)

    // Byte-exact reassembly is visible in the persisted assistant message.
    guard case .assistant(_, let calls) = transcript.messages[2] else {
      return XCTFail("expected assistant tool-call message")
    }
    XCTAssertEqual(calls[0].arguments, arguments)

    // The tool actually received the parsed arguments.
    guard case .tool(let callId, let name, let content, let isError) = transcript.messages[3] else {
      return XCTFail("expected tool result")
    }
    XCTAssertEqual(callId, "call_1")
    XCTAssertEqual(name, "Echo")
    XCTAssertFalse(isError)
    XCTAssertTrue(content.contains("quoted"))

    // The second model call saw the tool result in its request.
    let secondRequestMessages = client.requests[1].messages
    XCTAssertTrue(secondRequestMessages.contains { message in
      if case .tool(let id, _, _, _) = message { return id == "call_1" }
      return false
    })
  }

  func testParallelInterleavedCallsBothExecute() async {
    let (loop, _) = makeLoop(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "a", name: "Echo", argumentsFragment: #"{"n":"#),
        .toolCallDelta(index: 1, id: "b", name: "Echo", argumentsFragment: #"{"n":"#),
        .toolCallDelta(index: 0, id: nil, name: nil, argumentsFragment: "1}"),
        .toolCallDelta(index: 1, id: nil, name: nil, argumentsFragment: "2}"),
        .finish(.toolCalls),
      ]),
      .events([.textDelta("ok"), .finish(.stop)]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)

    let transcript = lastTranscript(in: events)!
    assertTranscriptIsAPIValid(transcript)
    let toolResults = transcript.messages.compactMap { message -> String? in
      if case .tool(let id, _, _, _) = message { return id }
      return nil
    }
    XCTAssertEqual(toolResults, ["a", "b"], "results append in call order")
  }

  func testMissingToolCallIdIsSynthesizedAndPaired() async {
    let (loop, _) = makeLoop(scripts: [
      .events([
        .toolCallDelta(index: 0, id: nil, name: "Echo", argumentsFragment: "{}"),
        .finish(.toolCalls),
      ]),
      .events([.finish(.stop)]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)
    let transcript = lastTranscript(in: events)!
    assertTranscriptIsAPIValid(transcript)
    guard case .assistant(_, let calls) = transcript.messages[2] else {
      return XCTFail("expected assistant message")
    }
    XCTAssertTrue(calls[0].id.hasPrefix("call_0_"))
  }

  // MARK: - Model-visible failures keep the loop alive

  func testInvalidJSONArgumentsBecomeErrorResultAndLoopContinues() async {
    let (loop, client) = makeLoop(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "bad", name: "Echo", argumentsFragment: "not json at all"),
        .finish(.toolCalls),
      ]),
      .events([.textDelta("recovered"), .finish(.stop)]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)
    XCTAssertEqual(client.requests.count, 2)

    let transcript = lastTranscript(in: events)!
    assertTranscriptIsAPIValid(transcript)
    guard case .tool(_, _, let content, let isError) = transcript.messages[3] else {
      return XCTFail("expected tool result")
    }
    XCTAssertTrue(isError)
    XCTAssertTrue(content.contains("valid JSON"), "instructive message, got: \(content)")
  }

  func testUnknownToolNameBecomesErrorResult() async {
    let (loop, _) = makeLoop(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "x", name: "Nonexistent", argumentsFragment: "{}"),
        .finish(.toolCalls),
      ]),
      .events([.finish(.stop)]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)
    let transcript = lastTranscript(in: events)!
    guard case .tool(_, _, let content, let isError) = transcript.messages[3] else {
      return XCTFail("expected tool result")
    }
    XCTAssertTrue(isError)
    XCTAssertTrue(content.contains("Unknown tool"))
  }

  func testThrowingToolBecomesErrorResult() async {
    let (loop, _) = makeLoop(
      scripts: [
        .events([
          .toolCallDelta(index: 0, id: "x", name: "Boom", argumentsFragment: "{}"),
          .finish(.toolCalls),
        ]),
        .events([.finish(.stop)]),
      ],
      tools: [ThrowingTool()]
    )

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)
    let transcript = lastTranscript(in: events)!
    guard case .tool(_, _, let content, let isError) = transcript.messages[3] else {
      return XCTFail("expected tool result")
    }
    XCTAssertTrue(isError)
    XCTAssertTrue(content.contains("boom"))
  }

  // MARK: - Turn cap

  func testMaxTurnsExceededThrowsAfterCap() async {
    let (loop, client) = makeLoop(
      scripts: [
        .events([
          .toolCallDelta(index: 0, id: "loop", name: "Echo", argumentsFragment: "{}"),
          .finish(.toolCalls),
        ])
      ],
      configuration: AgentLoopConfiguration(maxTurns: 3)
    )

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)

    guard case AgentHarnessError.maxTurnsExceeded(let turns)? = error as? AgentHarnessError else {
      return XCTFail("expected maxTurnsExceeded, got \(String(describing: error))")
    }
    XCTAssertEqual(turns, 3)
    XCTAssertEqual(client.requests.count, 3)

    let starts = events.filter { if case .turnStarted = $0 { return true } else { return false } }
    XCTAssertEqual(starts.count, 3)

    let transcript = lastTranscript(in: events)!
    assertTranscriptIsAPIValid(transcript)
    guard case .assistant(let text, let calls) = transcript.messages.last else {
      return XCTFail("expected trailing note")
    }
    XCTAssertTrue(calls.isEmpty)
    XCTAssertTrue(text?.contains("maximum") == true)
  }

  // MARK: - Usage

  func testUsageAccumulatesAcrossTurns() async {
    let (loop, _) = makeLoop(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "a", name: "Echo", argumentsFragment: "{}"),
        .usage(AgentTokenUsage(inputTokens: 10, outputTokens: 5, cachedInputTokens: 2)),
        .finish(.toolCalls),
      ]),
      .events([
        .textDelta("done"),
        .usage(AgentTokenUsage(inputTokens: 7, outputTokens: 3, cachedInputTokens: 1)),
        .finish(.stop),
      ]),
    ])

    let (events, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertNil(error)

    let usages = events.compactMap { if case .usageUpdated(let usage) = $0 { return usage } else { return nil } }
    XCTAssertEqual(usages.count, 2)
    XCTAssertEqual(usages[0], AgentTokenUsage(inputTokens: 10, outputTokens: 5, cachedInputTokens: 2))
    XCTAssertEqual(usages[1], AgentTokenUsage(inputTokens: 17, outputTokens: 8, cachedInputTokens: 3))
  }

  // MARK: - Streaming decision

  func testStreamingDisabledWhenToolsPresentAndStreamingToolCallsUnsupported() async {
    let capabilities = ModelCapabilities(supportsStreamingToolCalls: false)
    let (loop, client) = makeLoop(
      scripts: [.events([.textDelta("hi"), .finish(.stop)])],
      capabilities: capabilities
    )

    _ = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertEqual(client.requests[0].stream, false)
  }

  func testStreamingEnabledWithoutTools() async {
    let capabilities = ModelCapabilities(supportsStreamingToolCalls: false)
    let (loop, client) = makeLoop(
      scripts: [.events([.textDelta("hi"), .finish(.stop)])],
      tools: [],
      capabilities: capabilities
    )

    _ = await runLoopToEnd(loop, transcript: seedTranscript)
    XCTAssertEqual(client.requests[0].stream, true)
  }

  // MARK: - Context budget

  func testIrreducibleContextThrows() async {
    let big = String(repeating: "x", count: 4_000)
    let transcript = AgentTranscript(messages: [.system(big), .user([.text(big)])])
    let (loop, _) = makeLoop(
      scripts: [.events([.finish(.stop)])],
      configuration: AgentLoopConfiguration(contextWindowTokens: 100, outputReserveTokens: 0)
    )

    let (_, error) = await runLoopToEnd(loop, transcript: transcript)
    guard case AgentHarnessError.contextWindowExceeded? = error as? AgentHarnessError else {
      return XCTFail("expected contextWindowExceeded, got \(String(describing: error))")
    }
  }

  // MARK: - Timeout

  func testNoDataTimeoutFailsTheRun() async {
    let (loop, _) = makeLoop(
      scripts: [.hang(after: [.textDelta("partial")])],
      configuration: AgentLoopConfiguration(noDataTimeout: .milliseconds(200))
    )

    let start = ContinuousClock.now
    let (_, error) = await runLoopToEnd(loop, transcript: seedTranscript)
    let elapsed = start.duration(to: .now)

    guard case AgentHarnessError.streamTimeout? = error as? AgentHarnessError else {
      return XCTFail("expected streamTimeout, got \(String(describing: error))")
    }
    XCTAssertLessThan(elapsed, .seconds(5), "watchdog should fire promptly")
  }

  // MARK: - Cancellation

  func testCancellationMidStreamEndsPromptlyAndAllObservedTranscriptsAreValid() async {
    let (loop, _) = makeLoop(
      scripts: [.hang(after: [.textDelta("partial answer")])],
      configuration: AgentLoopConfiguration(noDataTimeout: .seconds(60))
    )

    let collector = LoopEventCollector()
    let stream = await loop.run(transcript: seedTranscript, model: "m")
    let consumer = Task {
      do {
        for try await event in stream {
          await collector.add(event)
        }
        await collector.finish(error: nil)
      } catch {
        await collector.finish(error: error)
      }
    }

    await collector.waitUntil { events, _ in
      events.contains { if case .assistantTextDelta = $0 { return true } else { return false } }
    }
    consumer.cancel()

    let start = ContinuousClock.now
    _ = await consumer.value
    XCTAssertLessThan(start.duration(to: .now), .seconds(5), "cancellation must not hang")

    for transcript in await collector.transcripts {
      assertTranscriptIsAPIValid(transcript)
    }
  }

  func testCancellationDuringSlowToolExecutionLeavesValidTranscripts() async {
    let (loop, _) = makeLoop(
      scripts: [
        .events([
          .toolCallDelta(index: 0, id: "slow", name: "Slow", argumentsFragment: "{}"),
          .finish(.toolCalls),
        ])
      ],
      tools: [SlowTool()]
    )

    let collector = LoopEventCollector()
    let stream = await loop.run(transcript: seedTranscript, model: "m")
    let consumer = Task {
      do {
        for try await event in stream {
          await collector.add(event)
        }
        await collector.finish(error: nil)
      } catch {
        await collector.finish(error: error)
      }
    }

    await collector.waitUntil { events, _ in
      events.contains { if case .toolExecutionStarted = $0 { return true } else { return false } }
    }
    consumer.cancel()

    let start = ContinuousClock.now
    _ = await consumer.value
    XCTAssertLessThan(start.duration(to: .now), .seconds(5), "slow tool must be cancelled, not awaited")

    // Every transcript the consumer managed to observe must be persistable.
    for transcript in await collector.transcripts {
      assertTranscriptIsAPIValid(transcript)
    }
  }
}
