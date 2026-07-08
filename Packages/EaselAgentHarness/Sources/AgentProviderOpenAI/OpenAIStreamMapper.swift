import AgentHarness
import Foundation
import SwiftOpenAI

/// Pure mapping from SwiftOpenAI response types onto `AgentModelEvent`s.
/// Internal and side-effect free so every branch is unit-testable from
/// JSON fixtures decoded into SwiftOpenAI's own types.
enum OpenAIStreamMapper {

  /// Events for one streamed chunk, excluding `.finish` — the client emits
  /// finish exactly once when the stream ends, from the last reason seen.
  static func events(for chunk: ChatCompletionChunkObject) -> [AgentModelEvent] {
    var events: [AgentModelEvent] = []
    if let choice = chunk.choices?.first, let delta = choice.delta {
      if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
        events.append(.reasoningDelta(reasoning))
      }
      if let content = delta.content, !content.isEmpty {
        events.append(.textDelta(content))
      }
      for (position, call) in (delta.toolCalls ?? []).enumerated() {
        events.append(
          .toolCallDelta(
            index: call.index ?? position,
            id: call.id,
            name: call.function.name,
            argumentsFragment: call.function.arguments
          )
        )
      }
    }
    if let usage = chunk.usage {
      events.append(.usage(tokenUsage(from: usage)))
    }
    return events
  }

  /// The finish reason carried by a chunk, if any.
  static func finishReason(for chunk: ChatCompletionChunkObject) -> AgentFinishReason? {
    guard let finish = chunk.choices?.first?.finishReason else { return nil }
    switch finish {
    case .string(let value):
      return finishReason(fromString: value)
    case .int(let value):
      return .other(String(value))
    }
  }

  static func finishReason(fromString value: String) -> AgentFinishReason {
    switch value {
    case "stop": return .stop
    case "tool_calls", "function_call": return .toolCalls
    case "length": return .length
    case "content_filter": return .contentFilter
    default: return .other(value)
    }
  }

  /// Synthesizes the full event sequence from a buffered (non-streamed)
  /// completion, in the same order a streamed response would produce.
  static func events(forBufferedCompletion completion: ChatCompletionObject) -> [AgentModelEvent] {
    var events: [AgentModelEvent] = []
    let choice = completion.choices?.first
    let message = choice?.message

    if let reasoning = message?.reasoningContent, !reasoning.isEmpty {
      events.append(.reasoningDelta(reasoning))
    }
    if let content = message?.content, !content.isEmpty {
      events.append(.textDelta(content))
    }
    for (position, call) in (message?.toolCalls ?? []).enumerated() {
      events.append(
        .toolCallDelta(
          index: call.index ?? position,
          id: call.id,
          name: call.function.name,
          argumentsFragment: call.function.arguments
        )
      )
    }
    if let usage = completion.usage {
      events.append(.usage(tokenUsage(from: usage)))
    }

    let sawToolCalls = !(message?.toolCalls ?? []).isEmpty
    let reason: AgentFinishReason
    switch choice?.finishReason {
    case .string(let value):
      reason = finishReason(fromString: value)
    case .int(let value):
      reason = .other(String(value))
    case nil:
      reason = sawToolCalls ? .toolCalls : .stop
    }
    events.append(.finish(reason))
    return events
  }

  static func tokenUsage(from usage: ChatUsage) -> AgentTokenUsage {
    AgentTokenUsage(
      inputTokens: usage.promptTokens ?? 0,
      outputTokens: usage.completionTokens ?? 0,
      cachedInputTokens: usage.promptTokensDetails?.cachedTokens ?? 0
    )
  }
}
