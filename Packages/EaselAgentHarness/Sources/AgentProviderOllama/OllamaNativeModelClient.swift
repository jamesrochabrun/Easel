import AgentHarness
import Foundation

/// Native Ollama client on POST /api/chat (NDJSON streaming).
///
/// Deliberately not Ollama's OpenAI-compatible /v1 shim, which has known bugs
/// combining streaming with tool calls. Native tool_calls arrive complete
/// (arguments as JSON objects): they are serialized, given synthesized ids,
/// and emitted as one `toolCallDelta` per call.
public struct OllamaNativeModelClient: AgentModelClient {
  public let profile: EndpointProfile
  private let sessionConfiguration: URLSessionConfiguration

  public var capabilities: ModelCapabilities { profile.capabilities }

  public init(profile: EndpointProfile) {
    let configuration = URLSessionConfiguration.default
    // First-token latency includes loading the model into memory.
    configuration.timeoutIntervalForRequest = 300
    self.init(profile: profile, sessionConfiguration: configuration)
  }

  /// Test seam: inject a configuration carrying a stub `URLProtocol`.
  init(profile: EndpointProfile, sessionConfiguration: URLSessionConfiguration) {
    self.profile = profile
    self.sessionConfiguration = sessionConfiguration
  }

  // MARK: - AgentModelClient

  public func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
    let body = OllamaRequestMapper.chatRequest(for: request, capabilities: capabilities)
    let urlRequest = try makeRequest(path: "/api/chat", body: body)
    let session = URLSession(configuration: sessionConfiguration)

    guard request.stream else {
      let (data, response) = try await perform { try await session.data(for: urlRequest) }
      try Self.checkHTTPStatus(response, body: data)
      let chunk: OllamaChatChunk
      do {
        chunk = try JSONDecoder().decode(OllamaChatChunk.self, from: data)
      } catch {
        throw AgentHarnessError.malformedResponse("Ollama returned an undecodable response: \(error.localizedDescription)")
      }
      var mapper = OllamaChunkMapper()
      let events = try mapper.events(for: chunk)
      return AsyncThrowingStream { continuation in
        for event in events { continuation.yield(event) }
        continuation.finish()
      }
    }

    let (bytes, response) = try await perform { try await session.bytes(for: urlRequest) }
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      var bodyData = Data()
      for try await byte in bytes.prefix(4_096) { bodyData.append(byte) }
      try Self.checkHTTPStatus(response, body: bodyData)
    }

    let (stream, continuation) = AsyncThrowingStream<AgentModelEvent, Error>.makeStream()
    let task = Task {
      var mapper = OllamaChunkMapper()
      var decodedAnyChunk = false
      do {
        for try await line in bytes.lines {
          let trimmed = line.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { continue }
          let chunk: OllamaChatChunk
          do {
            chunk = try JSONDecoder().decode(OllamaChatChunk.self, from: Data(trimmed.utf8))
          } catch {
            // A malformed line before any valid chunk means the endpoint is
            // not speaking this protocol; later glitches are skipped.
            if decodedAnyChunk { continue }
            throw AgentHarnessError.malformedResponse(
              "Ollama sent an unexpected response: \(String(trimmed.prefix(200)))"
            )
          }
          decodedAnyChunk = true
          for event in try mapper.events(for: chunk) {
            continuation.yield(event)
          }
        }
        continuation.finish()
      } catch {
        continuation.finish(throwing: Self.mapTransportError(error, baseURL: profile.baseURL))
      }
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }

  public func listModels() async throws -> [AgentModelInfo] {
    var urlRequest = try makeRequest(path: "/api/tags", body: Optional<OllamaChatRequest>.none)
    urlRequest.httpMethod = "GET"
    let session = URLSession(configuration: sessionConfiguration)
    let (data, response) = try await perform { try await session.data(for: urlRequest) }
    try Self.checkHTTPStatus(response, body: data)
    do {
      let tags = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
      return tags.models.map { AgentModelInfo(id: $0.name) }
    } catch {
      throw AgentHarnessError.malformedResponse("Could not decode /api/tags: \(error.localizedDescription)")
    }
  }

  // MARK: - Transport helpers

  private func makeRequest(path: String, body: (some Encodable)?) throws -> URLRequest {
    let base = profile.baseURL.hasSuffix("/") ? String(profile.baseURL.dropLast()) : profile.baseURL
    guard let url = URL(string: base + path) else {
      throw AgentHarnessError.network("Invalid Ollama base URL: \(profile.baseURL)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
    }
    return request
  }

  private func perform<T>(_ operation: () async throws -> T) async throws -> T {
    do {
      return try await operation()
    } catch {
      throw Self.mapTransportError(error, baseURL: profile.baseURL)
    }
  }

  static func mapTransportError(_ error: Error, baseURL: String) -> Error {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
        return AgentHarnessError.network(
          "Could not reach Ollama at \(baseURL) — is it running? (\(urlError.localizedDescription))"
        )
      case .timedOut:
        return AgentHarnessError.network("The request to Ollama timed out.")
      default:
        return AgentHarnessError.network(urlError.localizedDescription)
      }
    }
    return error
  }

  static func checkHTTPStatus(_ response: URLResponse, body: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard !(200...299).contains(http.statusCode) else { return }
    let serverError = (try? JSONDecoder().decode(OllamaChatChunk.self, from: body))?.error
    let detail = serverError ?? String(decoding: body.prefix(300), as: UTF8.self)
    if let serverError, serverError.contains("not found") {
      throw AgentHarnessError.modelNotFound(serverError)
    }
    throw AgentHarnessError.httpStatus(code: http.statusCode, body: detail)
  }
}

// MARK: - Chunk → event mapping

/// Stateful mapper for one response: numbers tool calls across chunks and
/// remembers whether any were seen so the finish reason stays truthful.
struct OllamaChunkMapper {
  private var nextToolCallIndex = 0
  private var sawToolCalls = false

  mutating func events(for chunk: OllamaChatChunk) throws -> [AgentModelEvent] {
    if let error = chunk.error {
      if error.contains("not found") {
        throw AgentHarnessError.modelNotFound(error)
      }
      throw AgentHarnessError.malformedResponse(error)
    }

    var events: [AgentModelEvent] = []
    if let message = chunk.message {
      if let thinking = message.thinking, !thinking.isEmpty {
        events.append(.reasoningDelta(thinking))
      }
      if let content = message.content, !content.isEmpty {
        events.append(.textDelta(content))
      }
      for call in message.toolCalls ?? [] {
        let index = nextToolCallIndex
        nextToolCallIndex += 1
        sawToolCalls = true
        let arguments = (try? call.function.arguments.encodedString()) ?? "{}"
        events.append(
          .toolCallDelta(
            index: index,
            id: "call_\(index)_\(UUID().uuidString.prefix(8).lowercased())",
            name: call.function.name,
            argumentsFragment: arguments
          )
        )
      }
    }

    if chunk.done == true {
      if chunk.promptEvalCount != nil || chunk.evalCount != nil {
        events.append(
          .usage(
            AgentTokenUsage(
              inputTokens: chunk.promptEvalCount ?? 0,
              outputTokens: chunk.evalCount ?? 0
            )
          )
        )
      }
      events.append(.finish(finishReason(doneReason: chunk.doneReason)))
    }
    return events
  }

  private func finishReason(doneReason: String?) -> AgentFinishReason {
    if sawToolCalls { return .toolCalls }
    switch doneReason {
    case "stop", nil: return .stop
    case "length": return .length
    case .some(let other): return .other(other)
    }
  }
}

// MARK: - Request mapping

enum OllamaRequestMapper {

  static func chatRequest(
    for request: AgentModelRequest,
    capabilities: ModelCapabilities
  ) -> OllamaChatRequest {
    OllamaChatRequest(
      model: request.model,
      messages: request.messages.map(message(_:)),
      tools: request.tools.isEmpty ? nil : request.tools.map(tool(_:)),
      stream: request.stream,
      options: OllamaOptions(
        numCtx: capabilities.contextWindowTokens,
        numPredict: request.maxOutputTokens,
        temperature: request.temperature
      )
    )
  }

  static func message(_ message: AgentMessage) -> OllamaChatMessage {
    switch message {
    case .system(let text):
      return OllamaChatMessage(role: "system", content: text)

    case .user(let blocks):
      var text: [String] = []
      var images: [String] = []
      for block in blocks {
        switch block {
        case .text(let value):
          text.append(value)
        case .imageDataURL(let dataURL):
          // Ollama takes raw base64 payloads, not data URLs.
          if let base64 = dataURL.components(separatedBy: "base64,").last, !base64.isEmpty {
            images.append(base64)
          }
        }
      }
      return OllamaChatMessage(
        role: "user",
        content: text.joined(separator: "\n"),
        images: images.isEmpty ? nil : images
      )

    case .assistant(let text, let toolCalls):
      return OllamaChatMessage(
        role: "assistant",
        content: text ?? "",
        toolCalls: toolCalls.isEmpty ? nil : toolCalls.map { call in
          OllamaToolCall(
            function: OllamaFunctionCall(
              name: call.name,
              arguments: (try? JSONValue(parsing: call.arguments)) ?? .object([:])
            )
          )
        }
      )

    case .tool(_, let name, let content, let isError):
      return OllamaChatMessage(
        role: "tool",
        content: isError ? "[error] \(content)" : content,
        toolName: name
      )
    }
  }

  static func tool(_ schema: AgentToolSchema) -> OllamaTool {
    OllamaTool(
      function: OllamaToolFunction(
        name: schema.name,
        description: schema.description,
        parameters: schema.parameters
      )
    )
  }
}
