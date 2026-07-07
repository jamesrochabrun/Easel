//
//  APIChatRuntime.swift
//  ClaudeCodeUI
//

import AgentHarness
import AgentProviderOllama
import AgentProviderOpenAI
import AgentTools
import Foundation

/// `ChatRuntime` for the `.api` provider: raw LLM APIs (local model servers,
/// on-device MLX, hosted OpenAI-compatible endpoints) driven by the in-app
/// agentic harness (`AgentLoop` + built-in workspace tools).
///
/// Mirrors `CodexChatRuntime`'s discipline: all UI output flows through
/// `ChatMessageDisplay`, sessions are tagged in `SessionManager`, and the
/// `activeGeneration` token prevents a superseded turn from writing into a
/// switched session or workspace.
@MainActor
final class APIChatRuntime: ChatRuntime {
  let provider: ChatProvider = .api
  var workingDirectory: String?

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

  private var isCancelled = false
  private(set) var activeGeneration = 0
  /// One toolset per session so the read-before-edit registry remembers
  /// earlier turns' Reads.
  private var sessionToolset: [any AgentTool]?

  var activeSessionId: String? {
    sessionManager.currentSessionId
  }

  init(
    messageDisplay: ChatMessageDisplay,
    sessionManager: SessionManager,
    workingDirectory: String? = nil,
    transcriptStore: any AgentTranscriptStore = NoOpAgentTranscriptStore(),
    credentialStore: any CredentialStore = KeychainCredentialStore(),
    clientFactory: @escaping @Sendable (EndpointProfile, String?) -> any AgentModelClient = APIChatRuntime.defaultClientFactory,
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

  nonisolated static let defaultClientFactory: @Sendable (EndpointProfile, String?) -> any AgentModelClient = { profile, apiKey in
    switch profile.kind {
    case .ollamaNative:
      return OllamaNativeModelClient(profile: profile)
    case .openAICompatible:
      return OpenAICompatibleModelClient(profile: profile, apiKey: apiKey)
    case .mlxLocal:
      // The MLX-aware factory is injected by the embedding app; this default
      // keeps ClaudeCodeCore free of the heavy MLX dependency.
      return UnavailableModelClient(
        profile: profile,
        reason: "On-device MLX inference is not available in this build."
      )
    }
  }

  func markSessionRestored() {}

  func resetSession() {
    isCancelled = false
    activeGeneration &+= 1
    sessionToolset = nil
  }

  func cancel() {
    isCancelled = true
    activeGeneration &+= 1
  }

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    isCancelled = false
    activeGeneration &+= 1
    let generation = activeGeneration

    guard let profile else {
      throw APIChatRuntimeError.missingProfile
    }
    let model = (modelIdentifier ?? "").isEmpty ? profile.defaultModel : modelIdentifier!
    guard !model.isEmpty else {
      throw APIChatRuntimeError.missingModel
    }
    guard let workingDirectory, !workingDirectory.isEmpty else {
      throw APIChatRuntimeError.missingWorkingDirectory
    }

    let sessionId = ensureSessionExists(firstMessageInSession: firstMessageInSession)

    // Assemble the transcript: stored history, refreshed system prompt, new user turn.
    var transcript = (try? await transcriptStore.loadTranscript(sessionId: sessionId)) ?? AgentTranscript()
    guard activeGeneration == generation, !isCancelled else { return }
    applySystemInstructions(to: &transcript)
    transcript.messages.append(.user(userContent(for: prompt, profile: profile)))
    try? await transcriptStore.saveTranscript(transcript, sessionId: sessionId)

    let workingDirectoryURL = URL(fileURLWithPath: workingDirectory)
    let context = ToolExecutionContext(
      workingDirectory: workingDirectoryURL,
      pathPolicy: PathConfinementPolicy(root: workingDirectoryURL)
    )
    let tools = currentToolset()
    let apiKey = try? credentialStore.apiKey(for: profile.id)
    let contextWindow = profile.capabilities.contextWindowTokens
    let configuration = AgentLoopConfiguration(
      maxTurns: maxTurns,
      allowParallelToolExecution: true,
      contextWindowTokens: contextWindow,
      outputReserveTokens: min(4_096, contextWindow / 4)
    )
    let loop = AgentLoop(
      client: clientFactory(profile, apiKey),
      tools: tools,
      configuration: configuration,
      context: context
    )

    let mapper = APIMessageMapper(firstAssistantMessageId: messageId, messageDisplay: messageDisplay)
    var lastRecordedUsage = AgentTokenUsage()
    var executedToolCount = 0
    var finalAssistantText: String?
    var latestTranscript = transcript

    do {
      for try await event in await loop.run(transcript: transcript, model: model) {
        guard activeGeneration == generation, !isCancelled, !Task.isCancelled else {
          break
        }
        mapper.handle(event)
        switch event {
        case .toolExecutionStarted:
          executedToolCount += 1
        case .completed(let text):
          finalAssistantText = text
        case .transcriptUpdated(let updated):
          latestTranscript = updated
          try? await transcriptStore.saveTranscript(updated, sessionId: sessionId)
        case .usageUpdated(let cumulative):
          let delta = AgentTokenUsage(
            inputTokens: cumulative.inputTokens - lastRecordedUsage.inputTokens,
            outputTokens: cumulative.outputTokens - lastRecordedUsage.outputTokens,
            cachedInputTokens: cumulative.cachedInputTokens - lastRecordedUsage.cachedInputTokens
          )
          lastRecordedUsage = cumulative
          let record = SessionUsageRecord(
            provider: .api,
            modelIdentifier: "\(profile.name)/\(model)",
            inputTokens: delta.inputTokens,
            outputTokens: delta.outputTokens,
            cachedInputTokens: delta.cachedInputTokens
          )
          if record.hasUsage {
            onUsageRecorded?(record)
          }
        default:
          break
        }
      }
      guard activeGeneration == generation, !isCancelled, !Task.isCancelled else {
        mapper.finalize()
        return
      }
      mapper.finalize()

      // Recovery for weak models that paste a page into the chat instead of
      // calling Write: if the whole turn made no tool calls but the final
      // message contains a complete page, apply it so the preview updates.
      if executedToolCount == 0, let text = finalAssistantText {
        await applyPastedFilesIfNeeded(
          from: text,
          workingDirectory: workingDirectory,
          context: context,
          sessionId: sessionId,
          transcript: &latestTranscript
        )
      }
    } catch {
      mapper.finalize()
      if error is CancellationError { return }
      if let harnessError = error as? AgentHarnessError, harnessError == .cancelled { return }
      guard activeGeneration == generation else { return }
      throw error
    }
  }

  // MARK: - Private

  /// Writes files a weak model pasted into its final message (instead of
  /// calling Write) to disk, and renders a tool card for each so the user
  /// sees what happened. Only fires when the pasted set includes a complete
  /// page (`index.html`), which signals authoring intent rather than an
  /// explanatory snippet. Writes go through the path policy (workspace
  /// confinement, `resources/codebase-references/` denial). The 600ms file
  /// watcher reloads the preview automatically.
  private func applyPastedFilesIfNeeded(
    from text: String,
    workingDirectory: String,
    context: ToolExecutionContext,
    sessionId: String,
    transcript: inout AgentTranscript
  ) async {
    let files = CodeFileExtractor.extractFiles(from: text)
    guard CodeFileExtractor.containsEntryPoint(files) else { return }

    var appliedAny = false
    for file in files {
      guard let url = try? context.pathPolicy.resolveForWrite(file.relativePath) else { continue }
      do {
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try Data(file.content.utf8).write(to: url)
      } catch {
        continue
      }
      appliedAny = true
      let callId = "apply_\(UUID().uuidString.prefix(8).lowercased())"
      messageDisplay.addMessage(
        MessageFactory.toolUseMessage(
          toolName: "Write",
          input: "file_path: \(file.relativePath)",
          toolInputData: ToolInputData(parameters: ["file_path": file.relativePath]),
          toolUseID: callId
        )
      )
      let byteCount = file.content.utf8.count
      messageDisplay.addMessage(
        ChatMessage(
          role: .toolResult,
          content: "Saved \(file.relativePath) from the response (\(byteCount) bytes). The preview will reload.",
          messageType: .toolResult,
          toolName: "Write",
          toolUseID: callId,
          isError: false
        )
      )
    }

    guard appliedAny else { return }
    // Record the applied write in the transcript so a resumed session knows
    // the files exist on disk.
    transcript.messages.append(
      .assistant(text: "(Saved the code above to the project files.)", toolCalls: [])
    )
    try? await transcriptStore.saveTranscript(transcript, sessionId: sessionId)
  }

  private func ensureSessionExists(firstMessageInSession: String?) -> String {
    if let existing = sessionManager.currentSessionId {
      return existing
    }
    let sessionId = UUID().uuidString
    sessionManager.startNewSession(
      id: sessionId,
      firstMessage: firstMessageInSession ?? "New conversation",
      workingDirectory: workingDirectory,
      provider: .api
    )
    onSessionChange?(sessionId)
    return sessionId
  }

  /// The system message always reflects the CURRENT instructions (settings
  /// may have changed between sends), replacing any stored one.
  private func applySystemInstructions(to transcript: inout AgentTranscript) {
    guard let systemInstructions, !systemInstructions.isEmpty else { return }
    if case .system = transcript.messages.first {
      transcript.messages[0] = .system(systemInstructions)
    } else {
      transcript.messages.insert(.system(systemInstructions), at: 0)
    }
  }

  private func userContent(for prompt: String, profile: EndpointProfile) -> [AgentContentBlock] {
    guard profile.capabilities.supportsVision else {
      return [.text(prompt)]
    }
    return APIImageContentConverter.contentBlocks(for: prompt)
  }

  private func currentToolset() -> [any AgentTool] {
    if let sessionToolset {
      return sessionToolset
    }
    let tools = BuiltInToolset.makeTools()
    sessionToolset = tools
    return tools
  }
}

/// Placeholder client for profile kinds the current build cannot serve.
struct UnavailableModelClient: AgentModelClient {
  let profile: EndpointProfile
  let reason: String

  var capabilities: ModelCapabilities { profile.capabilities }

  func streamCompletion(
    _ request: AgentModelRequest
  ) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
    throw AgentHarnessError.network(reason)
  }

  func listModels() async throws -> [AgentModelInfo] {
    throw AgentHarnessError.network(reason)
  }
}

enum APIChatRuntimeError: LocalizedError {
  case missingProfile
  case missingModel
  case missingWorkingDirectory

  var errorDescription: String? {
    switch self {
    case .missingProfile:
      return "No endpoint is selected for the Local / API provider. Choose one in Settings."
    case .missingModel:
      return "No model is selected for the Local / API provider. Pick one in Settings."
    case .missingWorkingDirectory:
      return "Open a project before chatting — the Local / API provider works inside a project folder."
    }
  }
}
