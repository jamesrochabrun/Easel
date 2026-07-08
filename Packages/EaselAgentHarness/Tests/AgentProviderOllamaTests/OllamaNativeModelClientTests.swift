import Foundation
import XCTest
import AgentHarness
@testable import AgentProviderOllama

// MARK: - URLProtocol stub

final class OllamaStubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
  nonisolated(unsafe) static var lastRequestBody: Data?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let body = request.httpBody ?? request.httpBodyStream.map { stream -> Data in
      stream.open()
      defer { stream.close() }
      var data = Data()
      let bufferSize = 16_384
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }
      while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        guard read > 0 else { break }
        data.append(buffer, count: read)
      }
      return data
    }
    Self.lastRequestBody = body

    let (status, data) = Self.handler?(request) ?? (200, Data())
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/x-ndjson"]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

final class OllamaNativeModelClientTests: XCTestCase {

  private func makeClient() -> OllamaNativeModelClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OllamaStubURLProtocol.self]
    let profile = EndpointProfile.builtInPresets().first { $0.kind == .ollamaNative }!
    return OllamaNativeModelClient(profile: profile, sessionConfiguration: configuration)
  }

  private func stub(_ lines: [String], status: Int = 200) {
    let data = Data((lines.joined(separator: "\n") + "\n").utf8)
    OllamaStubURLProtocol.handler = { _ in (status, data) }
  }

  private func collect(
    _ request: AgentModelRequest
  ) async throws -> [AgentModelEvent] {
    var events: [AgentModelEvent] = []
    for try await event in try await makeClient().streamCompletion(request) {
      events.append(event)
    }
    return events
  }

  private var basicRequest: AgentModelRequest {
    AgentModelRequest(model: "qwen3", messages: [.user([.text("hi")])], stream: true)
  }

  override func tearDown() {
    OllamaStubURLProtocol.handler = nil
    OllamaStubURLProtocol.lastRequestBody = nil
    super.tearDown()
  }

  // MARK: - Streaming

  func testTextOnlyStream() async throws {
    stub([
      #"{"model":"qwen3","message":{"role":"assistant","content":"Hel"},"done":false}"#,
      #"{"model":"qwen3","message":{"role":"assistant","content":"lo"},"done":false}"#,
      #"{"model":"qwen3","message":{"role":"assistant","content":""},"done":true,"done_reason":"stop","prompt_eval_count":12,"eval_count":4}"#,
    ])

    let events = try await collect(basicRequest)

    let text = events.compactMap { if case .textDelta(let t) = $0 { return t } else { return nil } }.joined()
    XCTAssertEqual(text, "Hello")

    guard case .usage(let usage)? = events.dropLast().last else { return XCTFail("expected usage before finish") }
    XCTAssertEqual(usage, AgentTokenUsage(inputTokens: 12, outputTokens: 4))

    guard case .finish(let reason)? = events.last else { return XCTFail("expected finish last") }
    XCTAssertEqual(reason, .stop)
  }

  func testToolCallChunkEmitsCompleteSerializedCall() async throws {
    stub([
      #"{"message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"Read","arguments":{"file_path":"src/a.tsx","limit":10}}}]},"done":false}"#,
      #"{"message":{"role":"assistant","content":""},"done":true,"done_reason":"stop","prompt_eval_count":5,"eval_count":2}"#,
    ])

    let events = try await collect(basicRequest)

    guard case .toolCallDelta(let index, let id, let name, let fragment)? = events.first else {
      return XCTFail("expected toolCallDelta first, got \(events)")
    }
    XCTAssertEqual(index, 0)
    XCTAssertEqual(name, "Read")
    XCTAssertTrue(id?.hasPrefix("call_0_") == true)
    let parsed = try JSONValue(parsing: fragment)
    XCTAssertEqual(parsed["file_path"]?.stringValue, "src/a.tsx")
    XCTAssertEqual(parsed["limit"]?.intValue, 10)

    // Tool calls override done_reason "stop".
    guard case .finish(.toolCalls)? = events.last else {
      return XCTFail("expected finish(.toolCalls), got \(String(describing: events.last))")
    }
  }

  func testTwoToolCallsGetSequentialIndicesAndDistinctIds() async throws {
    stub([
      #"{"message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"Read","arguments":{}}},{"function":{"name":"Grep","arguments":{}}}]},"done":true}"#,
    ])

    let events = try await collect(basicRequest)
    let calls = events.compactMap { event -> (Int, String?)? in
      if case .toolCallDelta(let index, let id, _, _) = event { return (index, id) }
      return nil
    }
    XCTAssertEqual(calls.map(\.0), [0, 1])
    XCTAssertNotEqual(calls[0].1, calls[1].1)
  }

  func testThinkingMapsToReasoningDelta() async throws {
    stub([
      #"{"message":{"role":"assistant","content":"","thinking":"pondering"},"done":false}"#,
      #"{"message":{"role":"assistant","content":"answer"},"done":true,"done_reason":"stop"}"#,
    ])

    let events = try await collect(basicRequest)
    guard case .reasoningDelta(let thought)? = events.first else { return XCTFail("expected reasoningDelta") }
    XCTAssertEqual(thought, "pondering")
  }

  func testMalformedMiddleLineIsSkipped() async throws {
    stub([
      #"{"message":{"role":"assistant","content":"ok"},"done":false}"#,
      #"GARBAGE NOT JSON"#,
      #"{"message":{"role":"assistant","content":""},"done":true,"done_reason":"stop"}"#,
    ])

    let events = try await collect(basicRequest)
    guard case .finish(.stop)? = events.last else { return XCTFail("stream should survive one bad line") }
  }

  func testErrorPayloadForMissingModelThrowsModelNotFound() async throws {
    stub([#"{"error":"model \"nope\" not found, try pulling it first"}"#])

    do {
      _ = try await collect(basicRequest)
      XCTFail("expected throw")
    } catch let error as AgentHarnessError {
      guard case .modelNotFound = error else { return XCTFail("expected modelNotFound, got \(error)") }
    }
  }

  func testMalformedFirstLineThrows() async throws {
    stub(["<html>totally not ollama</html>"])
    do {
      _ = try await collect(basicRequest)
      XCTFail("expected throw")
    } catch let error as AgentHarnessError {
      guard case .malformedResponse = error else { return XCTFail("expected malformedResponse, got \(error)") }
    }
  }

  func testDoneReasonLengthMapsToLength() async throws {
    stub([#"{"message":{"role":"assistant","content":"x"},"done":true,"done_reason":"length"}"#])
    let events = try await collect(basicRequest)
    guard case .finish(.length)? = events.last else { return XCTFail("expected length") }
  }

  // MARK: - Non-streaming

  func testNonStreamingSynthesizesSameEventShape() async throws {
    stub([
      #"{"message":{"role":"assistant","content":"done","tool_calls":[{"function":{"name":"LS","arguments":{}}}]},"done":true,"done_reason":"stop","prompt_eval_count":3,"eval_count":1}"#,
    ])
    var request = basicRequest
    request.stream = false

    let events = try await collect(request)
    XCTAssertEqual(events.count, 4) // textDelta, toolCallDelta, usage, finish
    guard case .textDelta("done") = events[0],
          case .toolCallDelta = events[1],
          case .usage = events[2],
          case .finish(.toolCalls) = events[3]
    else { return XCTFail("unexpected event order: \(events)") }
  }

  // MARK: - Request encoding

  func testRequestEncodingIncludesToolsOptionsAndEchoedCalls() async throws {
    stub([#"{"message":{"role":"assistant","content":"ok"},"done":true,"done_reason":"stop"}"#])

    let request = AgentModelRequest(
      model: "qwen3",
      messages: [
        .system("sys"),
        .user([.text("look"), .imageDataURL("data:image/jpeg;base64,QUJD")]),
        .assistant(text: nil, toolCalls: [AgentToolCall(id: "c1", name: "Read", arguments: #"{"file_path":"a"}"#)]),
        .tool(callId: "c1", name: "Read", content: "failed to open", isError: true),
      ],
      tools: [AgentToolSchema(name: "Read", description: "reads a file", parameters: ["type": "object"])],
      temperature: 0.1,
      maxOutputTokens: 512,
      stream: true
    )
    _ = try await collect(request)

    let body = try XCTUnwrap(OllamaStubURLProtocol.lastRequestBody)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

    XCTAssertEqual(json["model"] as? String, "qwen3")
    XCTAssertEqual(json["stream"] as? Bool, true)

    let options = try XCTUnwrap(json["options"] as? [String: Any])
    XCTAssertEqual(options["num_ctx"] as? Int, 16_384)
    XCTAssertEqual(options["num_predict"] as? Int, 512)

    let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
    XCTAssertEqual(tools.count, 1)

    let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
    XCTAssertEqual(messages.count, 4)
    // Images become raw base64 without the data-URL prefix.
    let user = messages[1]
    XCTAssertEqual((user["images"] as? [String])?.first, "QUJD")
    // Assistant tool calls echo back with arguments as a JSON object.
    let assistant = messages[2]
    let echoed = try XCTUnwrap((assistant["tool_calls"] as? [[String: Any]])?.first?["function"] as? [String: Any])
    XCTAssertEqual(echoed["name"] as? String, "Read")
    XCTAssertNotNil(echoed["arguments"] as? [String: Any])
    // Error tool results carry the visible marker and the tool name.
    let tool = messages[3]
    XCTAssertEqual(tool["tool_name"] as? String, "Read")
    XCTAssertEqual(tool["content"] as? String, "[error] failed to open")
  }

  // MARK: - Model listing

  func testListModelsParsesTags() async throws {
    OllamaStubURLProtocol.handler = { request in
      XCTAssertTrue(request.url!.path.hasSuffix("/api/tags"))
      return (200, Data(#"{"models":[{"name":"qwen3:14b"},{"name":"llama3.3:latest"}]}"#.utf8))
    }
    let models = try await makeClient().listModels()
    XCTAssertEqual(models.map(\.id), ["qwen3:14b", "llama3.3:latest"])
  }
}
