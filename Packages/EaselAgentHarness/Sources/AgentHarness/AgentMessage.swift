import Foundation

/// A block of user-authored content.
public enum AgentContentBlock: Sendable, Codable, Equatable {
  case text(String)
  /// A base64 data URL, e.g. "data:image/jpeg;base64,...". Only sent to
  /// vision-capable models; other providers receive the original path text.
  case imageDataURL(String)
}

/// A single tool invocation requested by the model.
public struct AgentToolCall: Sendable, Codable, Equatable, Identifiable {
  /// Provider-assigned id, or synthesized ("call_<index>_<uuid8>") when the
  /// backend omits ids (e.g. Ollama native).
  public let id: String
  public let name: String
  /// Raw JSON string, exactly as accumulated from the stream.
  public let arguments: String

  public init(id: String, name: String, arguments: String) {
    self.id = id
    self.name = name
    self.arguments = arguments
  }
}

/// One entry in the API-shaped conversation transcript.
///
/// This is the model-context source of truth — distinct from the UI-shaped
/// `ChatMessage` rows the app renders. Tool calls and tool results must stay
/// paired: an `.assistant` with `toolCalls` must be followed by one `.tool`
/// per call id, or providers reject the transcript.
public enum AgentMessage: Sendable, Codable, Equatable {
  case system(String)
  case user([AgentContentBlock])
  case assistant(text: String?, toolCalls: [AgentToolCall])
  case tool(callId: String, name: String, content: String, isError: Bool)
}

/// The versioned, persistable conversation transcript for one session.
public struct AgentTranscript: Sendable, Codable, Equatable {
  public var version: Int
  public var messages: [AgentMessage]

  public init(version: Int = 1, messages: [AgentMessage] = []) {
    self.version = version
    self.messages = messages
  }
}
