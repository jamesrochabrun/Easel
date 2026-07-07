//
//  APIMessageMapper.swift
//  ClaudeCodeUI
//

import AgentHarness
import Foundation

/// Per-send translator from `AgentLoopEvent`s into the `ChatMessage` rows the
/// shared chat UI renders (analog of `CodexMessageMapper` + Codex's
/// `StreamState`). Because the harness uses Claude-style tool names, the
/// existing tool cards render these rows without changes.
@MainActor
final class APIMessageMapper {

  /// Pre-generated id for the first assistant bubble of this send
  /// (`ChatViewModel` allocates it so scrolling can anchor to it).
  private let firstAssistantMessageId: UUID
  private let messageDisplay: ChatMessageDisplay

  private var assistantBuffer = ""
  private var streamingAssistantMessageId: UUID?
  private var usedFirstMessageId = false

  private var thinkingBuffer = ""
  private var streamingThinkingMessageId: UUID?

  init(firstAssistantMessageId: UUID, messageDisplay: ChatMessageDisplay) {
    self.firstAssistantMessageId = firstAssistantMessageId
    self.messageDisplay = messageDisplay
  }

  func handle(_ event: AgentLoopEvent) {
    switch event {
    case .turnStarted:
      break

    case .assistantTextDelta(let delta):
      assistantBuffer += delta
      if let id = streamingAssistantMessageId {
        messageDisplay.updateMessage(id: id, content: assistantBuffer, isComplete: false, isError: false)
      } else {
        let id = nextAssistantMessageId()
        streamingAssistantMessageId = id
        messageDisplay.addMessage(
          MessageFactory.assistantMessage(id: id, content: assistantBuffer, isComplete: false)
        )
      }

    case .assistantReasoningDelta(let delta):
      thinkingBuffer += delta
      if let id = streamingThinkingMessageId {
        messageDisplay.updateMessage(id: id, content: thinkingBuffer, isComplete: false, isError: false)
      } else {
        let message = MessageFactory.thinkingMessage(content: thinkingBuffer)
        streamingThinkingMessageId = message.id
        messageDisplay.addMessage(message)
      }

    case .assistantMessageCompleted(let text, _):
      finishThinkingMessage()
      if let id = streamingAssistantMessageId {
        messageDisplay.updateMessage(id: id, content: assistantBuffer, isComplete: true, isError: false)
      } else if let text, !text.isEmpty {
        // Non-streamed turn (e.g. a backend without streamed tool calls):
        // the text arrives only here.
        messageDisplay.addMessage(
          MessageFactory.assistantMessage(id: nextAssistantMessageId(), content: text, isComplete: true)
        )
      }
      assistantBuffer = ""
      streamingAssistantMessageId = nil

    case .toolExecutionStarted(let call):
      messageDisplay.addMessage(Self.toolUseMessage(for: call))

    case .toolExecutionCompleted(let callId, let name, let result):
      messageDisplay.addMessage(
        ChatMessage(
          role: result.isError ? .toolError : .toolResult,
          content: result.content,
          messageType: result.isError ? .toolError : .toolResult,
          toolName: name,
          toolUseID: callId,
          isError: result.isError
        )
      )

    case .usageUpdated, .transcriptUpdated:
      break

    case .completed:
      finishThinkingMessage()
      if let id = streamingAssistantMessageId {
        messageDisplay.updateMessage(id: id, content: assistantBuffer, isComplete: true, isError: false)
        streamingAssistantMessageId = nil
      }
    }
  }

  /// Called when the send ends for any reason; closes any open bubbles so
  /// nothing is left spinning in the UI.
  func finalize() {
    finishThinkingMessage()
    if let id = streamingAssistantMessageId {
      messageDisplay.updateMessage(id: id, content: assistantBuffer, isComplete: true, isError: false)
      streamingAssistantMessageId = nil
    }
  }

  // MARK: - Private

  private func nextAssistantMessageId() -> UUID {
    if !usedFirstMessageId {
      usedFirstMessageId = true
      return firstAssistantMessageId
    }
    return UUID()
  }

  private func finishThinkingMessage() {
    if let id = streamingThinkingMessageId {
      messageDisplay.updateMessage(id: id, content: thinkingBuffer, isComplete: true, isError: false)
    }
    thinkingBuffer = ""
    streamingThinkingMessageId = nil
  }

  static func toolUseMessage(for call: AgentToolCall) -> ChatMessage {
    let parameters = displayParameters(forArguments: call.arguments)
    let inputSummary = parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: ", ")
    return MessageFactory.toolUseMessage(
      toolName: call.name,
      input: inputSummary,
      toolInputData: ToolInputData(parameters: parameters, rawParameters: rawParameters(forArguments: call.arguments)),
      toolUseID: call.id
    )
  }

  /// Top-level arguments as display strings (long values truncated so tool
  /// cards stay compact; the raw values travel in `rawParameters`).
  static func displayParameters(forArguments arguments: String) -> [String: String] {
    guard let object = (try? JSONValue(parsing: arguments))?.objectValue else { return [:] }
    var parameters: [String: String] = [:]
    for (key, value) in object {
      let rendered: String
      switch value {
      case .string(let string): rendered = string
      default: rendered = (try? value.encodedString()) ?? ""
      }
      parameters[key] = rendered.count > 200 ? String(rendered.prefix(200)) + "…" : rendered
    }
    return parameters
  }

  /// Full-fidelity values for tools whose cards render diffs (Edit/Write).
  static func rawParameters(forArguments arguments: String) -> [String: String]? {
    guard let object = (try? JSONValue(parsing: arguments))?.objectValue else { return nil }
    var parameters: [String: String] = [:]
    for (key, value) in object {
      switch value {
      case .string(let string): parameters[key] = string
      default: parameters[key] = (try? value.encodedString()) ?? ""
      }
    }
    return parameters.isEmpty ? nil : parameters
  }
}
