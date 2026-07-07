import Foundation

/// Cheap token estimation for context-budget decisions (chars/4 heuristic
/// plus a small per-message overhead). Intentionally conservative and
/// tokenizer-free — exact counts are the provider's business.
public enum TokenEstimator {
  static let perMessageOverhead = 4
  static let perImageEstimate = 1_100

  public static func estimateTokens(in text: String) -> Int {
    max(1, text.count / 4)
  }

  public static func estimateTokens(in message: AgentMessage) -> Int {
    let content: Int
    switch message {
    case .system(let text):
      content = estimateTokens(in: text)
    case .user(let blocks):
      content = blocks.reduce(0) { sum, block in
        switch block {
        case .text(let text): return sum + estimateTokens(in: text)
        case .imageDataURL: return sum + perImageEstimate
        }
      }
    case .assistant(let text, let toolCalls):
      content = estimateTokens(in: text ?? "")
        + toolCalls.reduce(0) { $0 + estimateTokens(in: $1.name) + estimateTokens(in: $1.arguments) }
    case .tool(_, let name, let toolContent, _):
      content = estimateTokens(in: name) + estimateTokens(in: toolContent)
    }
    return content + perMessageOverhead
  }

  public static func estimateTokens(in transcript: AgentTranscript) -> Int {
    transcript.messages.reduce(0) { $0 + estimateTokens(in: $1) }
  }
}
