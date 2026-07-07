import AgentHarness
import Foundation
import SwiftOpenAI

/// Adapter for any OpenAI-compatible /v1 endpoint via SwiftOpenAI's custom
/// base-URL support (LM Studio, llama.cpp, OpenRouter, Groq, DeepSeek, xAI…).
///
/// Workstream C replaces the stub bodies: streaming chunk → event mapping,
/// non-streaming synthesis fallback, and /v1/models listing.
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
    throw NotImplemented()
  }

  public func listModels() async throws -> [AgentModelInfo] {
    throw NotImplemented()
  }
}

private struct NotImplemented: Error, LocalizedError {
  var errorDescription: String? {
    "OpenAICompatibleModelClient is not implemented yet (workstream C)."
  }
}
