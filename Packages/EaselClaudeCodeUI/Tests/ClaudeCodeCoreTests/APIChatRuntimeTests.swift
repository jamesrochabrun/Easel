import AgentHarness
import Foundation
import XCTest
@testable import ClaudeCodeCore

@MainActor
final class APIChatRuntimeTests: XCTestCase {

  // MARK: - Test doubles

  enum ScriptedTurn {
    case events([AgentModelEvent])
    case hang(after: [AgentModelEvent])
  }

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

    private func recordAndPick(_ request: AgentModelRequest) -> ScriptedTurn {
      lock.lock()
      defer { lock.unlock() }
      _requests.append(request)
      return scripts[min(_requests.count - 1, scripts.count - 1)]
    }

    func streamCompletion(
      _ request: AgentModelRequest
    ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
      let turn = recordAndPick(request)
      return AsyncThrowingStream { continuation in
        switch turn {
        case .events(let events):
          for event in events { continuation.yield(event) }
          continuation.finish()
        case .hang(let events):
          for event in events { continuation.yield(event) }
        }
      }
    }

    func listModels() async throws -> [AgentModelInfo] { [] }
  }

  actor InMemoryTranscriptStore: AgentTranscriptStore {
    private(set) var transcripts: [String: AgentTranscript] = [:]

    func loadTranscript(sessionId: String) async throws -> AgentTranscript? {
      transcripts[sessionId]
    }

    func saveTranscript(_ transcript: AgentTranscript, sessionId: String) async throws {
      transcripts[sessionId] = transcript
    }

    func deleteTranscript(sessionId: String) async throws {
      transcripts[sessionId] = nil
    }

    func seed(_ transcript: AgentTranscript, sessionId: String) {
      transcripts[sessionId] = transcript
    }
  }

  // MARK: - Fixture

  private var workspace: URL!

  override func setUpWithError() throws {
    workspace = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("api-runtime-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: workspace)
  }

  private struct Fixture {
    let runtime: APIChatRuntime
    let store: MessageStore
    let sessionManager: SessionManager
    let transcripts: InMemoryTranscriptStore
    let client: ScriptedModelClient
    let usageRecords: () -> [SessionUsageRecord]
    let sessionChanges: () -> [String]
  }

  private func makeFixture(
    scripts: [ScriptedTurn],
    capabilities: ModelCapabilities = ModelCapabilities(),
    profile overrideProfile: EndpointProfile? = nil
  ) -> Fixture {
    let store = MessageStore()
    let sessionManager = SessionManager(sessionStorage: NoOpSessionStorage())
    let transcripts = InMemoryTranscriptStore()
    let client = ScriptedModelClient(capabilities: capabilities, scripts: scripts)

    final class Recorder: @unchecked Sendable {
      var usage: [SessionUsageRecord] = []
      var sessions: [String] = []
    }
    let recorder = Recorder()

    let runtime = APIChatRuntime(
      messageDisplay: store,
      sessionManager: sessionManager,
      workingDirectory: workspace.path,
      transcriptStore: transcripts,
      credentialStore: InMemoryCredentialStore(),
      clientFactory: { _, _ in client },
      onSessionChange: { recorder.sessions.append($0) },
      onUsageRecorded: { recorder.usage.append($0) }
    )
    var profile = overrideProfile
      ?? EndpointProfile.builtInPresets().first { $0.kind == .ollamaNative }!
    profile.capabilities = capabilities
    runtime.profile = profile
    runtime.modelIdentifier = "test-model"
    runtime.systemInstructions = "You are the test agent."
    return Fixture(
      runtime: runtime,
      store: store,
      sessionManager: sessionManager,
      transcripts: transcripts,
      client: client,
      usageRecords: { recorder.usage },
      sessionChanges: { recorder.sessions }
    )
  }

  // MARK: - Tests

  func testTextTurnMintsSessionRendersAssistantAndPersistsTranscript() async throws {
    let fixture = makeFixture(scripts: [
      .events([.textDelta("Hel"), .textDelta("lo"), .finish(.stop)])
    ])

    try await fixture.runtime.send(prompt: "hi there", messageId: UUID(), firstMessageInSession: "hi there")

    // Session minted, tagged .api, surfaced through the callback.
    let sessionId = try XCTUnwrap(fixture.sessionManager.currentSessionId)
    XCTAssertEqual(fixture.sessionChanges(), [sessionId])

    // Assistant bubble streamed then completed.
    let messages = fixture.store.getAllMessages()
    let assistant = try XCTUnwrap(messages.last { $0.role == .assistant })
    XCTAssertEqual(assistant.content, "Hello")
    XCTAssertTrue(assistant.isComplete)

    // Transcript persisted: refreshed system + user + assistant.
    let stored = try await fixture.transcripts.loadTranscript(sessionId: sessionId)
    let transcript = try XCTUnwrap(stored)
    XCTAssertEqual(transcript.messages.first, .system("You are the test agent."))
    XCTAssertEqual(transcript.messages[1], .user([.text("hi there")]))
    XCTAssertEqual(transcript.messages.last, .assistant(text: "Hello", toolCalls: []))
  }

  func testToolCallTurnRendersToolCardsAndResults() async throws {
    try "file contents here".write(
      to: workspace.appendingPathComponent("note.txt"),
      atomically: true,
      encoding: .utf8
    )
    let fixture = makeFixture(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "call_1", name: "Read", argumentsFragment: #"{"file_path":"note.txt"}"#),
        .finish(.toolCalls),
      ]),
      .events([.textDelta("done"), .finish(.stop)]),
    ])

    try await fixture.runtime.send(prompt: "read the note", messageId: UUID(), firstMessageInSession: nil)

    let messages = fixture.store.getAllMessages()
    let toolUse = try XCTUnwrap(messages.first { $0.messageType == .toolUse })
    XCTAssertEqual(toolUse.toolName, "Read")
    XCTAssertEqual(toolUse.toolUseID, "call_1")
    XCTAssertEqual(toolUse.toolInputData?.parameters["file_path"], "note.txt")

    let toolResult = try XCTUnwrap(messages.first { $0.messageType == .toolResult })
    XCTAssertEqual(toolResult.toolUseID, "call_1")
    XCTAssertTrue(toolResult.content.contains("file contents here"))

    // Second model call saw the tool result in the transcript.
    XCTAssertEqual(fixture.client.requests.count, 2)
    XCTAssertTrue(fixture.client.requests[1].messages.contains { message in
      if case .tool(let callId, _, _, _) = message { return callId == "call_1" }
      return false
    })
  }

  func testUsageDeltasProducePerTurnRecords() async throws {
    let fixture = makeFixture(scripts: [
      .events([
        .toolCallDelta(index: 0, id: "a", name: "LS", argumentsFragment: "{}"),
        .usage(AgentTokenUsage(inputTokens: 10, outputTokens: 5)),
        .finish(.toolCalls),
      ]),
      .events([
        .textDelta("ok"),
        .usage(AgentTokenUsage(inputTokens: 7, outputTokens: 3)),
        .finish(.stop),
      ]),
    ])

    try await fixture.runtime.send(prompt: "go", messageId: UUID(), firstMessageInSession: nil)

    let records = fixture.usageRecords()
    XCTAssertEqual(records.count, 2)
    XCTAssertEqual(records[0].inputTokens, 10)
    XCTAssertEqual(records[0].outputTokens, 5)
    XCTAssertEqual(records[1].inputTokens, 7)
    XCTAssertEqual(records[1].outputTokens, 3)
    XCTAssertEqual(records[0].provider, .api)
    XCTAssertEqual(records[0].modelIdentifier, "Ollama/test-model")
  }

  func testMissingConfigurationThrowsInstructiveErrors() async {
    let fixture = makeFixture(scripts: [.events([.finish(.stop)])])

    fixture.runtime.profile = nil
    do {
      try await fixture.runtime.send(prompt: "x", messageId: UUID(), firstMessageInSession: nil)
      XCTFail("expected missingProfile")
    } catch APIChatRuntimeError.missingProfile {
    } catch {
      XCTFail("expected missingProfile, got \(error)")
    }

    // A preset without a default model + empty selection → missingModel.
    var keylessProfile = EndpointProfile.builtInPresets()[0]
    keylessProfile.defaultModel = ""
    fixture.runtime.profile = keylessProfile
    fixture.runtime.modelIdentifier = ""
    do {
      try await fixture.runtime.send(prompt: "x", messageId: UUID(), firstMessageInSession: nil)
      XCTFail("expected missingModel")
    } catch APIChatRuntimeError.missingModel {
    } catch {
      XCTFail("expected missingModel, got \(error)")
    }

    fixture.runtime.modelIdentifier = "m"
    fixture.runtime.workingDirectory = nil
    do {
      try await fixture.runtime.send(prompt: "x", messageId: UUID(), firstMessageInSession: nil)
      XCTFail("expected missingWorkingDirectory")
    } catch APIChatRuntimeError.missingWorkingDirectory {
    } catch {
      XCTFail("expected missingWorkingDirectory, got \(error)")
    }
  }

  func testCancelMidStreamStopsWritesAndClosesBubble() async throws {
    let fixture = makeFixture(scripts: [
      .hang(after: [.textDelta("partial")])
    ])

    let sendTask = Task {
      try await fixture.runtime.send(prompt: "go", messageId: UUID(), firstMessageInSession: nil)
    }

    // Wait for the first delta to land in the store.
    for _ in 0..<200 {
      if fixture.store.getAllMessages().contains(where: { $0.role == .assistant }) { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(fixture.store.getAllMessages().contains { $0.role == .assistant })

    fixture.runtime.cancel()
    sendTask.cancel()
    _ = try? await sendTask.value

    // The streaming bubble was closed, not left spinning.
    let assistant = try XCTUnwrap(fixture.store.getAllMessages().last { $0.role == .assistant })
    XCTAssertTrue(assistant.isComplete)
  }

  func testStaleGenerationSendDoesNotWriteIntoSwitchedSession() async throws {
    let fixture = makeFixture(scripts: [
      .hang(after: [.textDelta("stale turn")])
    ])

    let sendTask = Task {
      try await fixture.runtime.send(prompt: "one", messageId: UUID(), firstMessageInSession: nil)
    }
    for _ in 0..<200 {
      if !fixture.store.getAllMessages().isEmpty { break }
      try await Task.sleep(for: .milliseconds(10))
    }

    let countBeforeReset = fixture.store.getAllMessages().count
    fixture.runtime.resetSession() // simulates a session/workspace switch
    sendTask.cancel()
    _ = try? await sendTask.value

    // No additional rows may appear after the generation bump.
    XCTAssertLessThanOrEqual(fixture.store.getAllMessages().count, countBeforeReset)
  }

  func testVisionProfileAttachesImageBlocks() async throws {
    // A prompt referencing a real image through the attachment marker.
    let imageURL = workspace.appendingPathComponent("shot.png")
    try makePNG(at: imageURL, width: 64, height: 64)
    let prompt = "Recreate this design\nAnalyze this image: \(imageURL.path)"

    var capabilities = ModelCapabilities()
    capabilities.supportsVision = true
    let fixture = makeFixture(
      scripts: [.events([.textDelta("ok"), .finish(.stop)])],
      capabilities: capabilities
    )

    try await fixture.runtime.send(prompt: prompt, messageId: UUID(), firstMessageInSession: nil)

    let request = try XCTUnwrap(fixture.client.requests.first)
    guard case .user(let blocks)? = request.messages.last(where: {
      if case .user = $0 { return true }
      return false
    }) else { return XCTFail("expected user message") }
    XCTAssertTrue(blocks.contains { if case .imageDataURL = $0 { return true } else { return false } })
  }

  func testResumedSessionGetsRefreshedSystemInstructions() async throws {
    let fixture = makeFixture(scripts: [.events([.textDelta("ok"), .finish(.stop)])])

    // Simulate an existing session with an outdated system prompt.
    fixture.sessionManager.startNewSession(
      id: "resumed-1", firstMessage: "old", workingDirectory: workspace.path, provider: .api
    )
    await fixture.transcripts.seed(
      AgentTranscript(messages: [.system("OLD INSTRUCTIONS"), .user([.text("old q")]), .assistant(text: "old a", toolCalls: [])]),
      sessionId: "resumed-1"
    )

    try await fixture.runtime.send(prompt: "new question", messageId: UUID(), firstMessageInSession: nil)

    let request = try XCTUnwrap(fixture.client.requests.first)
    XCTAssertEqual(request.messages.first, .system("You are the test agent."))
    // History retained.
    XCTAssertTrue(request.messages.contains(.assistant(text: "old a", toolCalls: [])))
  }

  // MARK: - Helpers

  private func makePNG(at url: URL, width: Int, height: Int) throws {
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
  }
}
