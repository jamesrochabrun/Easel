import AgentHarness
import Foundation
import MLXLMCommon

/// `AgentModelClient` backed by on-device MLX inference.
///
/// Stateless per call; the expensive state (the loaded model) lives in the
/// injected `MLXModelRuntime`. Each `streamCompletion` performs exactly one
/// completion — the agent loop owns tool execution and multi-turn control.
public struct MLXModelClient: AgentModelClient {
  public let profile: EndpointProfile
  private let runtime: MLXModelRuntime
  private let manager: MLXModelManager

  public var capabilities: ModelCapabilities { profile.capabilities }

  public init(profile: EndpointProfile, runtime: MLXModelRuntime, manager: MLXModelManager) {
    self.profile = profile
    self.runtime = runtime
    self.manager = manager
  }

  public func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
    let container = try await runtime.container(forRepoId: request.model)
    // Chat.Message is not Sendable; build it inside the perform closure from
    // the Sendable AgentMessage array.
    let agentMessages = request.messages
    let toolSpecs = request.tools.isEmpty ? nil : request.tools.map(MLXMessageMapper.toolSpec(_:))
    let parameters: GenerateParameters = {
      var value = GenerateParameters()
      if let temperature = request.temperature {
        value.temperature = Float(temperature)
      }
      if let maxTokens = request.maxOutputTokens {
        value.maxTokens = maxTokens
      }
      return value
    }()

    let (stream, continuation) = AsyncThrowingStream<AgentModelEvent, Error>.makeStream()
    let task = Task {
      do {
        try await container.perform { (context: ModelContext) in
          let chat = MLXMessageMapper.chat(from: agentMessages)
          let input = UserInput(chat: chat, tools: toolSpecs)
          let lmInput = try await context.processor.prepare(input: input)
          let generations = try MLXLMCommon.generate(
            input: lmInput,
            parameters: parameters,
            context: context
          )

          var toolCallIndex = 0
          var sawToolCalls = false
          for await generation in generations {
            try Task.checkCancellation()
            switch generation {
            case .chunk(let text):
              if !text.isEmpty {
                continuation.yield(.textDelta(text))
              }
            case .toolCall(let call):
              sawToolCalls = true
              let index = toolCallIndex
              toolCallIndex += 1
              continuation.yield(
                .toolCallDelta(
                  index: index,
                  id: call.id ?? "call_\(index)_\(UUID().uuidString.prefix(8).lowercased())",
                  name: call.function.name,
                  argumentsFragment: MLXMessageMapper.serializeArguments(call.function.arguments)
                )
              )
            case .info(let info):
              continuation.yield(
                .usage(
                  AgentTokenUsage(
                    inputTokens: info.promptTokenCount,
                    outputTokens: info.generationTokenCount
                  )
                )
              )
            @unknown default:
              break
            }
          }
          continuation.yield(.finish(sawToolCalls ? .toolCalls : .stop))
          continuation.finish()
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }

  /// Installed models (downloads are managed in settings, not here).
  public func listModels() async throws -> [AgentModelInfo] {
    let curated = Dictionary(
      MLXCuratedModels.all.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    return await manager.installedModels().map { installed in
      curated[installed.id]?.modelInfo ?? AgentModelInfo(id: installed.id)
    }
  }
}

/// Pure mapping between harness contracts and MLX chat types.
enum MLXMessageMapper {

  static func chat(from messages: [AgentMessage]) -> [Chat.Message] {
    messages.map { message in
      switch message {
      case .system(let text):
        return .system(text)

      case .user(let blocks):
        // Vision is off for MLX in v1: image blocks are dropped, the marker
        // text (with the file path) still reaches the model.
        let text = blocks
          .compactMap { block -> String? in
            if case .text(let value) = block { return value }
            return nil
          }
          .joined(separator: "\n")
        return .user(text)

      case .assistant(let text, let toolCalls):
        var chatMessage = Chat.Message.assistant(text ?? "")
        if !toolCalls.isEmpty {
          chatMessage.tool = .calls(toolCalls.map(mlxToolCall(_:)))
        }
        return chatMessage

      case .tool(let callId, _, let content, let isError):
        return .tool(isError ? "[error] \(content)" : content, id: callId)
      }
    }
  }

  static func mlxToolCall(_ call: AgentToolCall) -> MLXLMCommon.ToolCall {
    MLXLMCommon.ToolCall(
      function: .init(
        name: call.name,
        arguments: mlxArguments(fromJSONString: call.arguments)
      ),
      id: call.id
    )
  }

  /// Our raw JSON argument string → MLX's JSONValue dictionary, via a Codable
  /// round-trip (both sides are plain JSON models).
  static func mlxArguments(fromJSONString json: String) -> [String: MLXLMCommon.JSONValue] {
    guard let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String: MLXLMCommon.JSONValue].self, from: data)
    else { return [:] }
    return decoded
  }

  static func serializeArguments(_ arguments: [String: MLXLMCommon.JSONValue]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(arguments) else { return "{}" }
    return String(decoding: data, as: UTF8.self)
  }

  /// OpenAI-style function spec, the shape MLX chat templates expect.
  static func toolSpec(_ schema: AgentToolSchema) -> ToolSpec {
    [
      "type": "function",
      "function": [
        "name": schema.name,
        "description": schema.description,
        "parameters": jsonObject(from: schema.parameters),
      ] as [String: any Sendable],
    ]
  }

  private static func jsonObject(from value: AgentHarness.JSONValue) -> [String: any Sendable] {
    guard
      let data = try? JSONEncoder().encode(value),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: any Sendable]
    else { return [:] }
    return object
  }
}
