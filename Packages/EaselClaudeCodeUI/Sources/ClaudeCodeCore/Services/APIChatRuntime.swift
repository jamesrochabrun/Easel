//
//  APIChatRuntime.swift
//  ClaudeCodeUI
//

import AgentHarness
import AgentProviderOllama
import AgentProviderOpenAI
import Foundation

/// `ChatRuntime` for the `.api` provider: raw LLM APIs (local model servers,
/// on-device MLX, hosted OpenAI-compatible endpoints) driven by the in-app
/// agentic harness (`AgentLoop` + built-in workspace tools).
///
/// This is the PR0 stub that freezes the constructor shape for
/// `ChatViewModel` wiring. Workstream F replaces `send` with the real
/// implementation: session minting, transcript load/save, `AgentLoop`
/// consumption, and `APIMessageMapper` → `MessageStore` rendering.
@MainActor
final class APIChatRuntime: ChatRuntime {
  let provider: ChatProvider = .api
  var workingDirectory: String?
  private(set) var activeSessionId: String?

  /// Pushed from `ChatViewModel.configure(_:)` before each send.
  var profile: EndpointProfile?
  var modelIdentifier: String?
  var systemInstructions: String?
  var maxTurns: Int = 20
  var credentialStore: any CredentialStore

  /// Test seam: injects scripted clients instead of real network/MLX backends.
  var clientFactory: @Sendable (EndpointProfile, String?) -> any AgentModelClient

  private let messageDisplay: ChatMessageDisplay
  private let sessionManager: SessionManager
  private let transcriptStore: any AgentTranscriptStore
  private let onSessionChange: ((String) -> Void)?
  private let onUsageRecorded: ((SessionUsageRecord) -> Void)?

  init(
    messageDisplay: ChatMessageDisplay,
    sessionManager: SessionManager,
    workingDirectory: String? = nil,
    transcriptStore: any AgentTranscriptStore = NoOpAgentTranscriptStore(),
    credentialStore: any CredentialStore = InMemoryCredentialStore(),
    clientFactory: @escaping @Sendable (EndpointProfile, String?) -> any AgentModelClient = { profile, apiKey in
      switch profile.kind {
      case .ollamaNative:
        return OllamaNativeModelClient(profile: profile)
      case .openAICompatible, .mlxLocal:
        return OpenAICompatibleModelClient(profile: profile, apiKey: apiKey)
      }
    },
    onSessionChange: ((String) -> Void)? = nil,
    onUsageRecorded: ((SessionUsageRecord) -> Void)? = nil
  ) {
    self.messageDisplay = messageDisplay
    self.sessionManager = sessionManager
    self.workingDirectory = workingDirectory
    self.transcriptStore = transcriptStore
    self.credentialStore = credentialStore
    self.clientFactory = clientFactory
    self.onSessionChange = onSessionChange
    self.onUsageRecorded = onUsageRecorded
  }

  func markSessionRestored() {}

  func resetSession() {
    activeSessionId = nil
  }

  func cancel() {}

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    throw APIChatRuntimeError.notImplemented
  }
}

enum APIChatRuntimeError: LocalizedError {
  case notImplemented
  case missingProfile

  var errorDescription: String? {
    switch self {
    case .notImplemented:
      return "The Local / API provider is not available yet in this build."
    case .missingProfile:
      return "No endpoint profile is selected. Choose one in Settings."
    }
  }
}
