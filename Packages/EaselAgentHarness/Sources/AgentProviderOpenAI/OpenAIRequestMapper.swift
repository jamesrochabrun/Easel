import AgentHarness
import Foundation
import SwiftOpenAI

/// Pure mapping from the frozen `AgentHarness` request contracts onto
/// SwiftOpenAI's chat-completion parameter types. Internal and side-effect
/// free so every branch is unit-testable.
enum OpenAIRequestMapper {

  /// Builds the full `ChatCompletionParameters` for one agent-loop turn.
  ///
  /// - `stream_options.include_usage` is only attached for streamed requests
  ///   (servers reject it alongside `stream: false`).
  /// - `parallel_tool_calls` is only sent when tools are offered, since some
  ///   backends reject the field on plain completions.
  static func parameters(for request: AgentModelRequest) throws -> ChatCompletionParameters {
    let tools = try tools(for: request.tools)
    return ChatCompletionParameters(
      messages: messages(request.messages),
      model: .custom(request.model),
      tools: tools.isEmpty ? nil : tools,
      parallelToolCalls: request.tools.isEmpty ? nil : request.parallelToolCalls,
      maxTokens: request.maxOutputTokens,
      temperature: request.temperature,
      streamOptions: request.stream ? .init(includeUsage: true) : nil
    )
  }

  // MARK: Messages

  static func messages(_ messages: [AgentMessage]) -> [ChatCompletionParameters.Message] {
    messages.map(message(_:))
  }

  static func message(_ message: AgentMessage) -> ChatCompletionParameters.Message {
    switch message {
    case .system(let text):
      return .init(role: .system, content: .text(text))

    case .user(let blocks):
      return .init(role: .user, content: userContent(blocks))

    case .assistant(let text, let toolCalls):
      return .init(
        role: .assistant,
        // SwiftOpenAI cannot encode `content: null`; an empty string is
        // broadly accepted for tool-call-only assistant messages.
        content: .text(text ?? ""),
        toolCalls: toolCalls.isEmpty ? nil : toolCalls.map { call in
          ToolCall(
            id: call.id,
            function: FunctionCall(arguments: call.arguments, name: call.name)
          )
        }
      )

    case .tool(let callId, let name, let content, let isError):
      return .init(
        role: .tool,
        // The wire format has no error flag on tool messages, so error
        // results are prefixed to keep the signal visible to the model.
        content: .text(isError ? "[error] \(content)" : content),
        name: name,
        toolCallID: callId
      )
    }
  }

  /// Text-only user turns collapse into a plain string; turns with images
  /// become a content array with `image_url` parts carrying the data URLs.
  static func userContent(_ blocks: [AgentContentBlock]) -> ChatCompletionParameters.Message.ContentType {
    let hasImages = blocks.contains { if case .imageDataURL = $0 { return true } else { return false } }
    guard hasImages else {
      let text = blocks
        .compactMap { if case .text(let text) = $0 { return text } else { return nil } }
        .joined(separator: "\n")
      return .text(text)
    }
    let parts = blocks.map { block -> ChatCompletionParameters.Message.ContentType.MessageContent in
      switch block {
      case .text(let text):
        return .text(text)
      case .imageDataURL(let dataURL):
        guard let url = URL(string: dataURL) else {
          // Degrade unparseable data URLs to text so the mapping stays total.
          return .text(dataURL)
        }
        return .imageUrl(.init(url: url))
      }
    }
    return .contentArray(parts)
  }

  // MARK: Tools

  static func tools(for schemas: [AgentToolSchema]) throws -> [ChatCompletionParameters.Tool] {
    try schemas.map { .init(function: try chatFunction(for: $0)) }
  }

  /// Converts the contract's `JSONValue` JSON Schema into SwiftOpenAI's
  /// `JSONSchema` by round-tripping through its `Codable` conformance.
  static func chatFunction(for schema: AgentToolSchema) throws -> ChatCompletionParameters.ChatFunction {
    let data = try JSONEncoder().encode(schema.parameters)
    let jsonSchema: JSONSchema
    do {
      jsonSchema = try JSONDecoder().decode(JSONSchema.self, from: data)
    } catch {
      throw AgentHarnessError.malformedResponse(
        "Tool \"\(schema.name)\" uses JSON Schema constructs SwiftOpenAI cannot represent: \(error)"
      )
    }
    return .init(
      name: schema.name,
      strict: nil,
      description: schema.description,
      parameters: jsonSchema
    )
  }
}
