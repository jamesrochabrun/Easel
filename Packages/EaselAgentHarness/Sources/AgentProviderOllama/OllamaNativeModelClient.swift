import AgentHarness
import Foundation

/// Native Ollama client on POST /api/chat (NDJSON streaming).
///
/// Deliberately not Ollama's OpenAI-compatible /v1 shim, which has known bugs
/// combining streaming with tool calls. Native tool_calls arrive complete
/// (arguments as JSON objects): serialize them, synthesize ids, and emit one
/// `toolCallDelta` per call.
///
/// Workstream D replaces the stub bodies: NDJSON wire types + streaming client,
/// /api/tags model listing, num_ctx option from capabilities.
public struct OllamaNativeModelClient: AgentModelClient {
  public let profile: EndpointProfile

  public var capabilities: ModelCapabilities { profile.capabilities }

  public init(profile: EndpointProfile) {
    self.profile = profile
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
    "OllamaNativeModelClient is not implemented yet (workstream D)."
  }
}
