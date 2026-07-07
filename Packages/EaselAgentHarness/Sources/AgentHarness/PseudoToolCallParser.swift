import Foundation

/// Fallback for backends whose models emit tool calls as plain text instead
/// of structured `tool_calls` (e.g. qwen2.5-coder on older Ollama template
/// parsers, which prints `{"name": "LS", "arguments": {...}}` as content).
///
/// Only exact, whole-payload matches are recognized — either the entire
/// assistant text or the entire body of a fenced code block must be a JSON
/// object (or array of objects) whose `name` is a known tool. Prose that
/// merely mentions JSON is never converted.
enum PseudoToolCallParser {

  struct Result {
    let calls: [AgentToolCall]
    /// Assistant text minus the consumed payloads; nil when the whole text
    /// was tool-call JSON (so the transcript doesn't echo it redundantly).
    let residualText: String?
  }

  static func parse(text: String, knownToolNames: Set<String>) -> Result? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !knownToolNames.isEmpty else { return nil }

    // Candidate 1: the entire message is the payload.
    if let calls = calls(fromJSONCandidate: trimmed, knownToolNames: knownToolNames) {
      return Result(calls: calls, residualText: nil)
    }

    // Candidate 2: fenced code blocks (```json / ```bash / bare fences).
    var allCalls: [AgentToolCall] = []
    var residual = trimmed
    for block in fencedBlocks(in: trimmed) {
      if let calls = calls(fromJSONCandidate: block.body, knownToolNames: knownToolNames) {
        allCalls.append(contentsOf: calls)
        residual = residual.replacingOccurrences(of: block.fullMatch, with: "")
      }
    }
    guard !allCalls.isEmpty else { return nil }

    let cleaned = residual.trimmingCharacters(in: .whitespacesAndNewlines)
    return Result(calls: allCalls, residualText: cleaned.isEmpty ? nil : cleaned)
  }

  // MARK: - Private

  private static func calls(
    fromJSONCandidate candidate: String,
    knownToolNames: Set<String>
  ) -> [AgentToolCall]? {
    guard let value = try? JSONValue(parsing: candidate) else { return nil }

    let objects: [JSONValue]
    switch value {
    case .object:
      objects = [value]
    case .array(let items):
      guard !items.isEmpty else { return nil }
      objects = items
    default:
      return nil
    }

    var calls: [AgentToolCall] = []
    for (index, object) in objects.enumerated() {
      guard let name = object["name"]?.stringValue, knownToolNames.contains(name) else {
        // All entries must be recognizable tool calls, or none convert.
        return nil
      }
      let arguments = object["arguments"] ?? object["parameters"] ?? .object([:])
      guard case .object = arguments else { return nil }
      calls.append(
        AgentToolCall(
          id: "call_text_\(index)_\(UUID().uuidString.prefix(8).lowercased())",
          name: name,
          arguments: (try? arguments.encodedString()) ?? "{}"
        )
      )
    }
    return calls.isEmpty ? nil : calls
  }

  private struct FencedBlock {
    let fullMatch: String
    let body: String
  }

  private static func fencedBlocks(in text: String) -> [FencedBlock] {
    var blocks: [FencedBlock] = []
    // ``` optional-language \n body ``` — language tag (bash/json/…) ignored.
    let pattern = /```[a-zA-Z0-9_-]*\n([\s\S]*?)```/
    for match in text.matches(of: pattern) {
      blocks.append(
        FencedBlock(
          fullMatch: String(match.0),
          body: String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
        )
      )
    }
    return blocks
  }
}
