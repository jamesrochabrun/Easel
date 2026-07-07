import Foundation

/// A request for one model completion (one turn of the agent loop).
public struct AgentModelRequest: Sendable {
  public var model: String
  public var messages: [AgentMessage]
  /// Empty means no tools are offered on this call.
  public var tools: [AgentToolSchema]
  public var temperature: Double?
  public var maxOutputTokens: Int?
  public var parallelToolCalls: Bool
  /// Decided by the loop from `ModelCapabilities`; when false the adapter
  /// must perform a non-streaming request and synthesize the same events.
  public var stream: Bool

  public init(
    model: String,
    messages: [AgentMessage],
    tools: [AgentToolSchema] = [],
    temperature: Double? = nil,
    maxOutputTokens: Int? = nil,
    parallelToolCalls: Bool = true,
    stream: Bool = true
  ) {
    self.model = model
    self.messages = messages
    self.tools = tools
    self.temperature = temperature
    self.maxOutputTokens = maxOutputTokens
    self.parallelToolCalls = parallelToolCalls
    self.stream = stream
  }
}

/// Wire-format description of a tool offered to the model.
public struct AgentToolSchema: Sendable, Codable, Equatable {
  public let name: String
  public let description: String
  /// A JSON Schema object.
  public let parameters: JSONValue

  public init(name: String, description: String, parameters: JSONValue) {
    self.name = name
    self.description = description
    self.parameters = parameters
  }
}

public enum AgentFinishReason: Sendable, Equatable {
  case stop
  case toolCalls
  case length
  case contentFilter
  case other(String)
}

public struct AgentTokenUsage: Sendable, Codable, Equatable {
  public var inputTokens: Int
  public var outputTokens: Int
  public var cachedInputTokens: Int

  public init(inputTokens: Int = 0, outputTokens: Int = 0, cachedInputTokens: Int = 0) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.cachedInputTokens = cachedInputTokens
  }
}

/// A model advertised by an endpoint (from /v1/models, /api/tags, or a local catalog).
public struct AgentModelInfo: Sendable, Codable, Equatable, Identifiable {
  public let id: String
  public var displayName: String?
  public var contextLength: Int?

  public init(id: String, displayName: String? = nil, contextLength: Int? = nil) {
    self.id = id
    self.displayName = displayName
    self.contextLength = contextLength
  }
}

/// Events emitted while consuming one model completion.
public enum AgentModelEvent: Sendable {
  case textDelta(String)
  /// Reasoning/thinking tokens (e.g. DeepSeek-R1); rendered as thinking rows.
  case reasoningDelta(String)
  /// A tool-call fragment. OpenAI-style backends send the id/name in the first
  /// fragment and argument string fragments after; backends that produce
  /// complete calls (Ollama native, MLX) send one delta carrying everything.
  case toolCallDelta(index: Int, id: String?, name: String?, argumentsFragment: String)
  case usage(AgentTokenUsage)
  case finish(AgentFinishReason)
}

/// Abstraction over one model backend (OpenAI-compatible HTTP, Ollama native,
/// on-device MLX…). Implementations must be stateless per call and `Sendable`.
public protocol AgentModelClient: Sendable {
  var capabilities: ModelCapabilities { get }

  /// Performs one completion. When `request.stream` is false the adapter must
  /// still return a stream, synthesizing events from the buffered response so
  /// the loop has a single consumption path.
  func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error>

  /// Lists models available on this endpoint (for the settings model picker).
  func listModels() async throws -> [AgentModelInfo]
}
