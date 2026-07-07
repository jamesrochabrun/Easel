import Foundation

/// Per-endpoint capability flags. These drive graceful degradation: the loop
/// auto-disables streaming when a backend is known to mishandle streamed tool
/// calls, and the runtime only attaches image blocks when vision is supported.
public struct ModelCapabilities: Sendable, Codable, Equatable {
  public var supportsStreaming: Bool
  /// When false and tools are present, the loop falls back to a non-streaming
  /// request (the adapter synthesizes the same event sequence).
  public var supportsStreamingToolCalls: Bool
  public var supportsParallelToolCalls: Bool
  public var supportsVision: Bool
  public var contextWindowTokens: Int

  public init(
    supportsStreaming: Bool = true,
    supportsStreamingToolCalls: Bool = true,
    supportsParallelToolCalls: Bool = true,
    supportsVision: Bool = false,
    contextWindowTokens: Int = 32_768
  ) {
    self.supportsStreaming = supportsStreaming
    self.supportsStreamingToolCalls = supportsStreamingToolCalls
    self.supportsParallelToolCalls = supportsParallelToolCalls
    self.supportsVision = supportsVision
    self.contextWindowTokens = contextWindowTokens
  }
}
