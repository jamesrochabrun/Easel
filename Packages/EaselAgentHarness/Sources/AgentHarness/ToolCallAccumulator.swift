import Foundation

/// Reassembles streamed tool-call fragments into complete calls.
///
/// OpenAI-style backends send the id and name in the first fragment for an
/// index and argument-string fragments after; backends that emit complete
/// calls (Ollama native, MLX) send one fragment carrying everything. Both
/// converge here: ingest by index, concatenate, finalize.
struct ToolCallAccumulator {
  private struct Partial {
    var id: String?
    var name: String?
    var arguments = ""
  }

  private var partials: [Int: Partial] = [:]

  var isEmpty: Bool { partials.isEmpty }

  mutating func ingest(index: Int, id: String?, name: String?, fragment: String) {
    var partial = partials[index] ?? Partial()
    if let id, !id.isEmpty, partial.id == nil {
      partial.id = id
    }
    if let name, !name.isEmpty {
      // Some backends fragment the name too; most send it once.
      partial.name = (partial.name ?? "") + name
    }
    partial.arguments += fragment
    partials[index] = partial
  }

  /// Completed calls sorted by index. Missing ids are synthesized; empty
  /// arguments default to "{}". Argument JSON validity is NOT checked here —
  /// the loop turns unparseable arguments into a model-visible error result.
  func finalize() -> [AgentToolCall] {
    partials
      .sorted { $0.key < $1.key }
      .map { index, partial in
        AgentToolCall(
          id: partial.id ?? Self.synthesizeId(index: index),
          name: partial.name ?? "",
          arguments: partial.arguments.isEmpty ? "{}" : partial.arguments
        )
      }
  }

  private static func synthesizeId(index: Int) -> String {
    "call_\(index)_\(UUID().uuidString.prefix(8).lowercased())"
  }
}
