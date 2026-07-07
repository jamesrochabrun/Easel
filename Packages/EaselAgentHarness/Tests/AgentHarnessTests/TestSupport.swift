import Foundation
import XCTest
@testable import AgentHarness

// MARK: - Scripted model client

enum ScriptedTurn {
  case events([AgentModelEvent])
  /// Yields the given events, then never finishes (until cancelled).
  case hang(after: [AgentModelEvent])
  case failure(Error)
}

/// Replays canned per-call scripts and records every request it receives.
/// The last script repeats if the loop makes more calls than scripts.
final class ScriptedModelClient: AgentModelClient, @unchecked Sendable {
  let capabilities: ModelCapabilities
  private let scripts: [ScriptedTurn]
  private let lock = NSLock()
  private var _requests: [AgentModelRequest] = []

  init(capabilities: ModelCapabilities = ModelCapabilities(), scripts: [ScriptedTurn]) {
    self.capabilities = capabilities
    self.scripts = scripts
  }

  var requests: [AgentModelRequest] {
    lock.lock()
    defer { lock.unlock() }
    return _requests
  }

  private func recordAndPickTurn(_ request: AgentModelRequest) -> ScriptedTurn {
    lock.lock()
    defer { lock.unlock() }
    _requests.append(request)
    return scripts[min(_requests.count - 1, scripts.count - 1)]
  }

  func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
    let turn = recordAndPickTurn(request)
    return AsyncThrowingStream { continuation in
      switch turn {
      case .events(let events):
        for event in events { continuation.yield(event) }
        continuation.finish()
      case .hang(let events):
        for event in events { continuation.yield(event) }
        // Never finishes; consumer cancellation or watchdog ends it.
      case .failure(let error):
        continuation.finish(throwing: error)
      }
    }
  }

  func listModels() async throws -> [AgentModelInfo] { [] }
}

// MARK: - Test tools

struct EchoTool: AgentTool {
  let name = "Echo"
  let description = "Echoes its arguments"
  let parametersJSONSchema: JSONValue = ["type": "object"]
  let isReadOnly = true

  func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    ToolResult(content: "echo: \(try arguments.encodedString())")
  }
}

struct MutatingProbeTool: AgentTool {
  let name = "Write"
  let description = "Pretends to write"
  let parametersJSONSchema: JSONValue = ["type": "object"]
  let isReadOnly = false

  func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    ToolResult(content: "wrote: \(try arguments.encodedString())")
  }
}

struct SlowTool: AgentTool {
  let name = "Slow"
  let description = "Sleeps for a long time"
  let parametersJSONSchema: JSONValue = ["type": "object"]
  let isReadOnly = false

  func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    try await Task.sleep(for: .seconds(30))
    return ToolResult(content: "slept")
  }
}

struct ThrowingTool: AgentTool {
  struct Boom: Error, LocalizedError {
    var errorDescription: String? { "boom" }
  }

  let name = "Boom"
  let description = "Always fails"
  let parametersJSONSchema: JSONValue = ["type": "object"]
  let isReadOnly = false

  func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    throw Boom()
  }
}

// MARK: - Event collection

actor LoopEventCollector {
  private(set) var events: [AgentLoopEvent] = []
  private(set) var terminalError: Error?
  private(set) var finished = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func add(_ event: AgentLoopEvent) {
    events.append(event)
    resumeWaiters()
  }

  func finish(error: Error?) {
    terminalError = error
    finished = true
    resumeWaiters()
  }

  private func resumeWaiters() {
    let pending = waiters
    waiters = []
    for waiter in pending { waiter.resume() }
  }

  /// Suspends until the predicate matches the collected state (or the run finished).
  func waitUntil(_ predicate: @Sendable ([AgentLoopEvent], Bool) -> Bool) async {
    while !predicate(events, finished), !finished {
      await withCheckedContinuation { continuation in
        waiters.append(continuation)
      }
    }
  }

  var transcripts: [AgentTranscript] {
    events.compactMap {
      if case .transcriptUpdated(let transcript) = $0 { return transcript }
      return nil
    }
  }
}

// MARK: - Helpers

func makeToolContext() -> ToolExecutionContext {
  let root = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("agent-loop-tests-\(UUID().uuidString)")
  try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  return ToolExecutionContext(workingDirectory: root, pathPolicy: PathConfinementPolicy(root: root))
}

/// Runs the loop to completion, collecting every event and the terminal error.
func runLoopToEnd(
  _ loop: AgentLoop,
  transcript: AgentTranscript,
  model: String = "test-model"
) async -> (events: [AgentLoopEvent], error: Error?) {
  let collector = LoopEventCollector()
  do {
    for try await event in await loop.run(transcript: transcript, model: model) {
      await collector.add(event)
    }
    await collector.finish(error: nil)
  } catch {
    await collector.finish(error: error)
  }
  return (await collector.events, await collector.terminalError)
}

/// Asserts the transcript never dangles: every assistant tool call is
/// immediately followed by exactly its tool results.
func assertTranscriptIsAPIValid(
  _ transcript: AgentTranscript,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  var index = 0
  let messages = transcript.messages
  while index < messages.count {
    if case .assistant(_, let toolCalls) = messages[index], !toolCalls.isEmpty {
      var expected = toolCalls.map(\.id)
      var cursor = index + 1
      while !expected.isEmpty {
        guard cursor < messages.count, case .tool(let callId, _, _, _) = messages[cursor] else {
          XCTFail(
            "Dangling tool calls \(expected) after assistant at index \(index)",
            file: file,
            line: line
          )
          return
        }
        guard let position = expected.firstIndex(of: callId) else {
          XCTFail("Unexpected tool result \(callId) at index \(cursor)", file: file, line: line)
          return
        }
        expected.remove(at: position)
        cursor += 1
      }
      index = cursor
    } else {
      if case .tool(let callId, _, _, _) = messages[index] {
        XCTFail("Orphaned tool result \(callId) at index \(index)", file: file, line: line)
      }
      index += 1
    }
  }
}

func lastTranscript(in events: [AgentLoopEvent]) -> AgentTranscript? {
  for event in events.reversed() {
    if case .transcriptUpdated(let transcript) = event { return transcript }
  }
  return nil
}
