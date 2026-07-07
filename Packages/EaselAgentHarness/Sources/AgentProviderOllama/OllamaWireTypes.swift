import AgentHarness
import Foundation

// Wire types for Ollama's native chat API, per
// https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion
// All types are internal: the public surface is `OllamaNativeModelClient`.

// MARK: - POST /api/chat request

struct OllamaChatRequest: Encodable {
  var model: String
  var messages: [OllamaChatMessage]
  var tools: [OllamaTool]? = nil
  var stream: Bool
  var options: OllamaOptions? = nil
}

/// One conversation message. Used both when encoding requests and when
/// decoding the `message` object inside streamed response chunks.
struct OllamaChatMessage: Codable {
  /// "system", "user", "assistant", or "tool".
  var role: String
  var content: String? = nil
  /// Raw base64 payloads (no `data:` URL prefix), for multimodal models.
  var images: [String]? = nil
  /// Reasoning tokens from thinking models (streamed alongside `content`).
  var thinking: String? = nil
  /// On assistant messages: tool invocations (requested or echoed back).
  var toolCalls: [OllamaToolCall]? = nil
  /// On tool-role result messages: the name of the tool that was executed.
  var toolName: String? = nil

  enum CodingKeys: String, CodingKey {
    case role
    case content
    case images
    case thinking
    case toolCalls = "tool_calls"
    case toolName = "tool_name"
  }
}

struct OllamaToolCall: Codable {
  var function: OllamaFunctionCall
}

/// Unlike OpenAI-style APIs, `arguments` is a JSON object — not a string.
struct OllamaFunctionCall: Codable {
  var name: String
  var arguments: JSONValue
}

struct OllamaTool: Encodable {
  var type = "function"
  var function: OllamaToolFunction
}

struct OllamaToolFunction: Encodable {
  var name: String
  var description: String
  /// A JSON Schema object.
  var parameters: JSONValue
}

struct OllamaOptions: Encodable {
  var numCtx: Int? = nil
  var numPredict: Int? = nil
  var temperature: Double? = nil

  enum CodingKeys: String, CodingKey {
    case numCtx = "num_ctx"
    case numPredict = "num_predict"
    case temperature
  }
}

// MARK: - POST /api/chat response

/// One NDJSON line of a streamed response, the entire body of a non-streamed
/// response, or an `{"error": "..."}` failure payload.
struct OllamaChatChunk: Decodable {
  var model: String? = nil
  var createdAt: String? = nil
  var message: OllamaChatMessage? = nil
  var done: Bool? = nil
  /// "stop", "length", "load", "unload"… (final chunk only).
  var doneReason: String? = nil
  /// Prompt token count (final chunk only).
  var promptEvalCount: Int? = nil
  /// Completion token count (final chunk only).
  var evalCount: Int? = nil
  /// Server-reported failure, e.g. `model "x" not found, try pulling it first`.
  var error: String? = nil

  enum CodingKeys: String, CodingKey {
    case model
    case createdAt = "created_at"
    case message
    case done
    case doneReason = "done_reason"
    case promptEvalCount = "prompt_eval_count"
    case evalCount = "eval_count"
    case error
  }
}

// MARK: - GET /api/tags response

struct OllamaTagsResponse: Decodable {
  struct Model: Decodable {
    var name: String
  }

  var models: [Model]
}
