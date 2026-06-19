//
//  ClaudeChatRuntime.swift
//  ClaudeCodeUI
//

import ClaudeCodeSDK
import Foundation
import os.log

@MainActor
final class ClaudeChatRuntime: ChatRuntime {
  let provider: ChatProvider = .claude

  var workingDirectory: String? {
    get {
      claudeClient.configuration.workingDirectory
    }
    set {
      claudeClient.configuration.workingDirectory = newValue
    }
  }

  var activeSessionId: String? {
    streamProcessor.activeSessionId
  }

  private var claudeClient: ClaudeCode
  private let sessionManager: SessionManager
  private let streamProcessor: StreamProcessor
  private let globalPreferences: GlobalPreferencesStorage
  private let systemPromptPrefix: String?
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.ClaudeChat", category: "ClaudeChatRuntime")
  private let onError: (Error, ErrorOperation) -> Void
  private let onTokenUsageUpdate: (Int, Int) -> Void
  private let onCostUpdate: (Double) -> Void
  private let onUsageRecord: (SessionUsageRecord) -> Void
  private let onResultReceived: () -> Void

  init(
    claudeClient: ClaudeCode,
    sessionManager: SessionManager,
    streamProcessor: StreamProcessor,
    globalPreferences: GlobalPreferencesStorage,
    systemPromptPrefix: String?,
    onError: @escaping (Error, ErrorOperation) -> Void,
    onTokenUsageUpdate: @escaping (Int, Int) -> Void,
    onCostUpdate: @escaping (Double) -> Void,
    onUsageRecord: @escaping (SessionUsageRecord) -> Void,
    onResultReceived: @escaping () -> Void
  ) {
    self.claudeClient = claudeClient
    self.sessionManager = sessionManager
    self.streamProcessor = streamProcessor
    self.globalPreferences = globalPreferences
    self.systemPromptPrefix = systemPromptPrefix
    self.onError = onError
    self.onTokenUsageUpdate = onTokenUsageUpdate
    self.onCostUpdate = onCostUpdate
    self.onUsageRecord = onUsageRecord
    self.onResultReceived = onResultReceived
  }

  func markSessionRestored() {}

  func resetSession() {
    streamProcessor.cancelStream()
  }

  func cancel() {
    claudeClient.cancel()
    streamProcessor.cancelStream()
  }

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    if let sessionId = sessionManager.currentSessionId {
      try await continueConversation(
        sessionId: sessionId,
        prompt: prompt,
        messageId: messageId,
        firstMessageInSession: firstMessageInSession
      )
    } else {
      try await startNewConversation(
        prompt: prompt,
        messageId: messageId,
        firstMessageInSession: firstMessageInSession
      )
    }
  }

  private func startNewConversation(
    prompt: String,
    messageId: UUID,
    firstMessageInSession: String?
  ) async throws {
    if let existingId = sessionManager.currentSessionId {
      logger.warning("Starting new Claude conversation while session '\(existingId)' exists")
    }

    let result = try await claudeClient.runSinglePrompt(
      prompt: prompt,
      outputFormat: .streamJson,
      options: createOptions()
    )

    await processResult(result, messageId: messageId, firstMessageInSession: firstMessageInSession)
  }

  private func continueConversation(
    sessionId: String,
    prompt: String,
    messageId: UUID,
    firstMessageInSession: String?
  ) async throws {
    do {
      let result = try await claudeClient.resumeConversation(
        sessionId: sessionId,
        prompt: prompt,
        outputFormat: .streamJson,
        options: createOptions()
      )

      await processResult(result, messageId: messageId, firstMessageInSession: firstMessageInSession)
    } catch {
      let errorMessage = error.localizedDescription.lowercased()
      if errorMessage.contains("no conversation") || errorMessage.contains("not found") {
        logger.info("Claude session not found, starting a new conversation")
        try await startNewConversation(
          prompt: prompt,
          messageId: messageId,
          firstMessageInSession: firstMessageInSession
        )
      } else {
        throw error
      }
    }
  }

  private func createOptions() -> ClaudeCodeOptions {
    ClaudeChatRuntimeOptionsBuilder(
      globalPreferences: globalPreferences,
      systemPromptPrefix: systemPromptPrefix
    ).makeOptions()
  }

  private func processResult(
    _ result: ClaudeCodeResult,
    messageId: UUID,
    firstMessageInSession: String?
  ) async {
    switch result {
    case .stream(let publisher):
      await streamProcessor.processStream(
        publisher,
        messageId: messageId,
        firstMessageInSession: firstMessageInSession,
        onError: { [onError] error in
          onError(error, .streaming)
        },
        onTokenUsageUpdate: onTokenUsageUpdate,
        onCostUpdate: onCostUpdate,
        onUsageRecord: onUsageRecord,
        onResultReceived: onResultReceived
      )

    default:
      let error = NSError(
        domain: "ClaudeChatRuntime",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"]
      )
      onError(error, .streaming)
    }
  }
}
