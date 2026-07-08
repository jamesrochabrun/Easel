import AgentHarness
import Foundation
import SwiftOpenAI

/// Adapter for any OpenAI-compatible /v1 endpoint via SwiftOpenAI's custom
/// base-URL support (LM Studio, llama.cpp, OpenRouter, Groq, DeepSeek, xAI…).
public struct OpenAICompatibleModelClient: AgentModelClient {
  public let profile: EndpointProfile
  private let apiKey: String?

  public var capabilities: ModelCapabilities { profile.capabilities }

  public init(profile: EndpointProfile, apiKey: String?) {
    self.profile = profile
    self.apiKey = apiKey
  }

  public func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
    let parameters = try OpenAIRequestMapper.parameters(for: request)
    let service = makeService()

    guard request.stream else {
      let completion: ChatCompletionObject
      do {
        completion = try await service.startChat(parameters: parameters)
      } catch {
        throw Self.mapError(error)
      }
      let events = OpenAIStreamMapper.events(forBufferedCompletion: completion)
      return AsyncThrowingStream { continuation in
        for event in events { continuation.yield(event) }
        continuation.finish()
      }
    }

    let upstream: AsyncThrowingStream<ChatCompletionChunkObject, Error>
    do {
      upstream = try await service.startStreamedChat(parameters: parameters)
    } catch {
      throw Self.mapError(error)
    }

    let (stream, continuation) = AsyncThrowingStream<AgentModelEvent, Error>.makeStream()
    let task = Task {
      var lastFinishReason: AgentFinishReason?
      var sawToolCalls = false
      do {
        for try await chunk in upstream {
          for event in OpenAIStreamMapper.events(for: chunk) {
            if case .toolCallDelta = event { sawToolCalls = true }
            continuation.yield(event)
          }
          if let reason = OpenAIStreamMapper.finishReason(for: chunk) {
            lastFinishReason = reason
          }
        }
        // Some backends report finish_reason "stop" even when tool calls
        // were streamed; the accumulator is authoritative, but keep the
        // reason coherent for consumers that inspect it.
        let reason = lastFinishReason ?? (sawToolCalls ? .toolCalls : .stop)
        continuation.yield(.finish(reason))
        continuation.finish()
      } catch {
        continuation.finish(throwing: Self.mapError(error))
      }
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }

  public func listModels() async throws -> [AgentModelInfo] {
    do {
      let response = try await makeService().listModels()
      return response.data.map { AgentModelInfo(id: $0.id) }
    } catch {
      throw Self.mapError(error)
    }
  }

  // MARK: - Service construction

  /// Services are constructed per call: they are lightweight wrappers around
  /// a URLSession-backed HTTP client, and not storing one keeps this struct
  /// `Sendable` without `@unchecked` tricks.
  private func makeService() -> OpenAIService {
    let parsed = Self.parseBaseURL(profile.baseURL)
    return OpenAIServiceFactory.service(
      apiKey: apiKey ?? "",
      overrideBaseURL: parsed.root,
      proxyPath: parsed.proxyPath,
      overrideVersion: parsed.version,
      extraHeaders: profile.extraHeaders.isEmpty ? nil : profile.extraHeaders
    )
  }

  struct ParsedBaseURL: Equatable {
    var root: String
    var proxyPath: String?
    var version: String?
  }

  /// Splits a user-entered base URL into SwiftOpenAI's factory components.
  /// "https://api.groq.com/openai/v1" → root "https://api.groq.com",
  /// proxyPath "openai", version "v1". A missing version component defaults
  /// to "v1" (every OpenAI-compatible server uses it).
  static func parseBaseURL(_ raw: String) -> ParsedBaseURL {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard
      let components = URLComponents(string: trimmed),
      let scheme = components.scheme,
      let host = components.host
    else {
      return ParsedBaseURL(root: trimmed, proxyPath: nil, version: nil)
    }

    var root = "\(scheme)://\(host)"
    if let port = components.port {
      root += ":\(port)"
    }

    var pathParts = components.path.split(separator: "/").map(String.init)
    var version: String?
    if let last = pathParts.last, last.wholeMatch(of: /v\d+[a-z]*/) != nil {
      version = last
      pathParts.removeLast()
    }
    return ParsedBaseURL(
      root: root,
      proxyPath: pathParts.isEmpty ? nil : pathParts.joined(separator: "/"),
      version: version
    )
  }

  // MARK: - Error mapping

  static func mapError(_ error: Error) -> Error {
    if let apiError = error as? APIError {
      switch apiError {
      case .responseUnsuccessful(let description, let statusCode):
        if statusCode == 401 || statusCode == 403 {
          return AgentHarnessError.httpStatus(code: statusCode, body: description)
        }
        if statusCode == 404, description.lowercased().contains("model") {
          return AgentHarnessError.modelNotFound(description)
        }
        return AgentHarnessError.httpStatus(code: statusCode, body: description)
      case .timeOutError:
        return AgentHarnessError.network("The request timed out.")
      default:
        return AgentHarnessError.network(apiError.displayDescription)
      }
    }
    if let urlError = error as? URLError {
      return AgentHarnessError.network(urlError.localizedDescription)
    }
    return error
  }
}
