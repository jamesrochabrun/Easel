import Foundation

/// Fallback for backends whose models emit tool calls as plain text instead
/// of structured `tool_calls` (e.g. qwen2.5-coder on Ollama template parsers,
/// which print `{"name": "Write", "parameters": {...}}` as content — bare,
/// fenced, or mixed into prose).
///
/// Only balanced JSON objects (or arrays of them) whose `name` matches a known
/// tool are recognized. Prose that merely mentions a tool name is never
/// converted. Recognized payloads are removed from the residual text so the
/// assistant bubble shows only the human-readable part.
enum PseudoToolCallParser {

  struct Result {
    let calls: [AgentToolCall]
    /// Assistant text with the consumed JSON payloads removed; nil when
    /// nothing readable remains (so the transcript doesn't echo raw JSON).
    let residualText: String?
  }

  static func parse(text: String, knownToolNames: Set<String>) -> Result? {
    guard !knownToolNames.isEmpty else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    var calls: [AgentToolCall] = []
    var residual = trimmed
    var index = 0

    for span in balancedJSONSpans(in: trimmed) {
      let candidate = String(trimmed[span])
      guard
        let extracted = toolCalls(
          fromJSONCandidate: candidate,
          knownToolNames: knownToolNames,
          startingAt: index,
          // An object sitting inline inside a sentence must carry an
          // arguments/parameters key to count — so a stray `{"name": "LS"}`
          // mention isn't executed. A call standing on its own line (or
          // fenced) is treated as intentional even with no arguments.
          requireArgumentsKey: isInline(span: span, in: trimmed)
        )
      else { continue }
      calls.append(contentsOf: extracted)
      index += extracted.count
      residual = residual.replacingOccurrences(of: candidate, with: "")
    }

    guard !calls.isEmpty else { return nil }

    // Clean up leftover code fences / whitespace around the removed payloads.
    residual = residual
      .replacingOccurrences(of: "```json", with: "")
      .replacingOccurrences(of: "```bash", with: "")
      .replacingOccurrences(of: "```", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return Result(calls: calls, residualText: residual.isEmpty ? nil : residual)
  }

  // MARK: - JSON candidate → tool calls

  private static func toolCalls(
    fromJSONCandidate candidate: String,
    knownToolNames: Set<String>,
    startingAt startIndex: Int,
    requireArgumentsKey: Bool
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
    for (offset, object) in objects.enumerated() {
      guard let name = object["name"]?.stringValue, knownToolNames.contains(name) else {
        // Every entry must be a recognizable tool call, or none convert.
        return nil
      }
      let argumentsValue = object["arguments"] ?? object["parameters"]
      if requireArgumentsKey, argumentsValue == nil {
        return nil
      }
      let arguments = argumentsValue ?? .object([:])
      guard case .object = arguments else { return nil }
      calls.append(
        AgentToolCall(
          id: "call_text_\(startIndex + offset)_\(UUID().uuidString.prefix(8).lowercased())",
          name: name,
          arguments: (try? arguments.encodedString()) ?? "{}"
        )
      )
    }
    return calls.isEmpty ? nil : calls
  }

  /// True when prose text hugs the JSON object on the same line (before or
  /// after it), ignoring code-fence markers. Objects alone on their line —
  /// including fenced ones — are not inline.
  private static func isInline(span: Range<String.Index>, in text: String) -> Bool {
    func isFillerLine(_ segment: Substring) -> Bool {
      let stripped = segment.replacingOccurrences(of: "`", with: "")
        .trimmingCharacters(in: .whitespaces)
      return stripped.isEmpty
    }
    // Text on the same line before the object.
    var before = text[text.startIndex..<span.lowerBound]
    if let newline = before.lastIndex(of: "\n") {
      before = before[before.index(after: newline)...]
    }
    // Text on the same line after the object.
    var after = text[span.upperBound..<text.endIndex]
    if let newline = after.firstIndex(of: "\n") {
      after = after[..<newline]
    }
    return !isFillerLine(before) || !isFillerLine(after)
  }

  // MARK: - Balanced-brace scanning

  /// Ranges of top-level balanced `{…}` / `[…]` substrings, respecting quoted
  /// strings and escapes so a brace inside a string value never terminates the
  /// object early.
  private static func balancedJSONSpans(in text: String) -> [Range<String.Index>] {
    var spans: [Range<String.Index>] = []
    var depth = 0
    var start: String.Index?
    var inString = false
    var escaping = false
    var opener: Character = "{"

    var i = text.startIndex
    while i < text.endIndex {
      let character = text[i]
      if inString {
        if escaping {
          escaping = false
        } else if character == "\\" {
          escaping = true
        } else if character == "\"" {
          inString = false
        }
      } else {
        switch character {
        case "\"":
          inString = true
        case "{", "[":
          if depth == 0 {
            start = i
            opener = character
          }
          // Only count the bracket kind we opened with, so `{ "a": [1] }`
          // is one span rather than closing early on `]`.
          if (opener == "{" && character == "{") || (opener == "[" && character == "[") {
            depth += 1
          }
        case "}", "]":
          if (opener == "{" && character == "}") || (opener == "[" && character == "]") {
            depth -= 1
            if depth == 0, let openStart = start {
              spans.append(openStart..<text.index(after: i))
              start = nil
            }
          }
        default:
          break
        }
      }
      i = text.index(after: i)
    }
    return spans
  }
}
