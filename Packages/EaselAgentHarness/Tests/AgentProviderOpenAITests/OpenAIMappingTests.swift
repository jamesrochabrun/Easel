import Foundation
import XCTest
import AgentHarness
import SwiftOpenAI
@testable import AgentProviderOpenAI

final class OpenAIMappingTests: XCTestCase {

  private func decodeChunk(_ json: String) throws -> ChatCompletionChunkObject {
    // SwiftOpenAI's response types carry explicit snake_case CodingKeys, so
    // fixtures decode with a plain decoder — same as the SDK's wire path.
    try JSONDecoder().decode(ChatCompletionChunkObject.self, from: Data(json.utf8))
  }

  // MARK: - Chunk → events

  func testTextChunkMapsToTextDelta() throws {
    let chunk = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{"content":"Hel"},"finish_reason":null}]}
    """)
    let events = OpenAIStreamMapper.events(for: chunk)
    XCTAssertEqual(events.count, 1)
    guard case .textDelta(let text) = events[0] else { return XCTFail("expected textDelta") }
    XCTAssertEqual(text, "Hel")
    XCTAssertNil(OpenAIStreamMapper.finishReason(for: chunk))
  }

  func testReasoningContentMapsToReasoningDelta() throws {
    let chunk = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{"reasoning_content":"thinking…"},"finish_reason":null}]}
    """)
    let events = OpenAIStreamMapper.events(for: chunk)
    guard case .reasoningDelta(let text)? = events.first else { return XCTFail("expected reasoningDelta") }
    XCTAssertEqual(text, "thinking…")
  }

  func testFragmentedToolCallChunksCarryIndexIdNameAndArguments() throws {
    let first = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{"tool_calls":[
      {"index":0,"id":"call_a","type":"function","function":{"name":"Edit","arguments":""}}
    ]},"finish_reason":null}]}
    """)
    let second = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{"tool_calls":[
      {"index":0,"function":{"arguments":"{\\"file"}}
    ]},"finish_reason":null}]}
    """)

    guard case .toolCallDelta(let index0, let id0, let name0, let frag0)? =
      OpenAIStreamMapper.events(for: first).first
    else { return XCTFail("expected toolCallDelta") }
    XCTAssertEqual(index0, 0)
    XCTAssertEqual(id0, "call_a")
    XCTAssertEqual(name0, "Edit")
    XCTAssertEqual(frag0, "")

    guard case .toolCallDelta(let index1, let id1, let name1, let frag1)? =
      OpenAIStreamMapper.events(for: second).first
    else { return XCTFail("expected toolCallDelta") }
    XCTAssertEqual(index1, 0)
    XCTAssertNil(id1)
    XCTAssertNil(name1)
    XCTAssertEqual(frag1, "{\"file")
  }

  func testParallelToolCallsInOneChunkKeepDistinctIndices() throws {
    let chunk = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{"tool_calls":[
      {"index":0,"id":"a","function":{"name":"Read","arguments":"{}"}},
      {"index":1,"id":"b","function":{"name":"Grep","arguments":"{}"}}
    ]},"finish_reason":null}]}
    """)
    let events = OpenAIStreamMapper.events(for: chunk)
    XCTAssertEqual(events.count, 2)
    guard case .toolCallDelta(let i0, _, _, _) = events[0],
          case .toolCallDelta(let i1, _, _, _) = events[1]
    else { return XCTFail("expected two toolCallDeltas") }
    XCTAssertEqual([i0, i1], [0, 1])
  }

  func testUsageChunkMapsToUsageEvent() throws {
    let chunk = try decodeChunk("""
    {"id":"c1","choices":[],
     "usage":{"prompt_tokens":100,"completion_tokens":25,"total_tokens":125,
              "prompt_tokens_details":{"cached_tokens":40}}}
    """)
    let events = OpenAIStreamMapper.events(for: chunk)
    guard case .usage(let usage)? = events.first else { return XCTFail("expected usage") }
    XCTAssertEqual(usage, AgentTokenUsage(inputTokens: 100, outputTokens: 25, cachedInputTokens: 40))
  }

  func testFinishReasonMapping() throws {
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "stop"), .stop)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "tool_calls"), .toolCalls)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "function_call"), .toolCalls)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "length"), .length)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "content_filter"), .contentFilter)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(fromString: "weird"), .other("weird"))

    let chunk = try decodeChunk("""
    {"id":"c1","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
    """)
    XCTAssertEqual(OpenAIStreamMapper.finishReason(for: chunk), .toolCalls)
  }

  // MARK: - Request mapping

  func testRequestMapsMessagesToolsAndOptions() throws {
    let request = AgentModelRequest(
      model: "qwen3",
      messages: [
        .system("sys"),
        .user([.text("hi")]),
        .assistant(text: nil, toolCalls: [AgentToolCall(id: "c1", name: "Read", arguments: #"{"file_path":"a"}"#)]),
        .tool(callId: "c1", name: "Read", content: "data", isError: false),
        .tool(callId: "c2", name: "Bash", content: "boom", isError: true),
      ],
      tools: [AgentToolSchema(name: "Read", description: "reads", parameters: ["type": "object"])],
      temperature: 0.2,
      parallelToolCalls: true,
      stream: true
    )

    let parameters = try OpenAIRequestMapper.parameters(for: request)
    XCTAssertEqual(parameters.messages.count, 5)
    XCTAssertEqual(parameters.tools?.count, 1)
    XCTAssertEqual(parameters.parallelToolCalls, true)
    XCTAssertEqual(parameters.temperature, 0.2)

    // Error tool results carry a visible marker (the wire format has no flag).
    let encoded = try JSONEncoder().encode(parameters)
    let json = String(decoding: encoded, as: UTF8.self)
    XCTAssertTrue(json.contains("[error] boom"))
  }

  func testNonStreamingRequestOmitsStreamOptions() throws {
    let request = AgentModelRequest(model: "m", messages: [.user([.text("x")])], stream: false)
    let parameters = try OpenAIRequestMapper.parameters(for: request)
    let json = String(decoding: try JSONEncoder().encode(parameters), as: UTF8.self)
    XCTAssertFalse(json.contains("include_usage"))
  }

  func testUserMessageWithImageBecomesContentArray() throws {
    let dataURL = "data:image/jpeg;base64,AAAA"
    let message = OpenAIRequestMapper.message(.user([.text("look"), .imageDataURL(dataURL)]))
    let json = String(decoding: try JSONEncoder().encode(message), as: UTF8.self)
    XCTAssertTrue(json.contains("image_url"), json)
    XCTAssertTrue(json.contains("AAAA"), json)
  }

  // MARK: - Base URL parsing

  func testBaseURLParsing() {
    typealias Parsed = OpenAICompatibleModelClient.ParsedBaseURL
    XCTAssertEqual(
      OpenAICompatibleModelClient.parseBaseURL("http://localhost:1234/v1"),
      Parsed(root: "http://localhost:1234", proxyPath: nil, version: "v1")
    )
    XCTAssertEqual(
      OpenAICompatibleModelClient.parseBaseURL("https://api.groq.com/openai/v1"),
      Parsed(root: "https://api.groq.com", proxyPath: "openai", version: "v1")
    )
    XCTAssertEqual(
      OpenAICompatibleModelClient.parseBaseURL("https://openrouter.ai/api/v1"),
      Parsed(root: "https://openrouter.ai", proxyPath: "api", version: "v1")
    )
    XCTAssertEqual(
      OpenAICompatibleModelClient.parseBaseURL("http://localhost:8080"),
      Parsed(root: "http://localhost:8080", proxyPath: nil, version: nil)
    )
    XCTAssertEqual(
      OpenAICompatibleModelClient.parseBaseURL("https://generativelanguage.googleapis.com/v1beta"),
      Parsed(root: "https://generativelanguage.googleapis.com", proxyPath: nil, version: "v1beta")
    )
  }

  // MARK: - Error mapping

  func testErrorMapping() {
    let unauthorized = OpenAICompatibleModelClient.mapError(
      APIError.responseUnsuccessful(description: "bad key", statusCode: 401)
    )
    guard case AgentHarnessError.httpStatus(let code, _)? = unauthorized as? AgentHarnessError else {
      return XCTFail("expected httpStatus")
    }
    XCTAssertEqual(code, 401)

    let network = OpenAICompatibleModelClient.mapError(URLError(.cannotConnectToHost))
    guard case AgentHarnessError.network? = network as? AgentHarnessError else {
      return XCTFail("expected network")
    }
  }
}
