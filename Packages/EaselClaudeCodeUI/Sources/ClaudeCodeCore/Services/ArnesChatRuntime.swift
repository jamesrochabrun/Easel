//
//  ArnesChatRuntime.swift
//  ClaudeCodeUI
//

import Foundation

/// Chat runtime for the Arnes CLI harness (OpenRouter models).
///
/// Each turn spawns `arnes do - --yes --output-format stream-json
/// --include-partial`, writes the prompt to stdin, and maps the one-JSON-
/// object-per-line event stream into chat messages. The first turn passes
/// `--session` so Arnes persists a transcript; later turns `--resume` it, so
/// conversation context lives in the CLI exactly as it does for Codex.
@MainActor
final class ArnesChatRuntime: ChatRuntime {
  let provider: ChatProvider = .arnes
  var workingDirectory: String?
  /// Instructions appended to the Arnes system prompt (`--append-system-prompt`).
  var systemInstructions: String?
  /// OpenRouter model slug; empty or `openrouter/auto` means provider routing.
  var modelIdentifier: String?
  /// User-overridden arnes command/path. Empty/nil means auto-detect.
  var commandOverride: String?
  /// Extra arguments appended to each launch.
  var extraArguments: [String]
  /// Environment variable overrides (e.g. OPENROUTER_API_KEY) injected into
  /// the arnes process.
  var environmentOverrides: [String: String]

  private let messageDisplay: ChatMessageDisplay
  private let sessionManager: SessionManager
  private let onSessionChange: ((String) -> Void)?
  private let onUsageRecorded: ((SessionUsageRecord) -> Void)?
  private let onCostUpdate: ((Double) -> Void)?
  private let onModelResolved: ((String) -> Void)?
  private var hasSession = false
  private var isCancelled = false
  private var activeProcess: Process?
  /// Monotonic token guarding a superseded turn against mutating shared
  /// state after the user switched sessions/workspaces. Same discipline as
  /// `CodexChatRuntime.activeGeneration`.
  private(set) var activeGeneration = 0

  var activeSessionId: String? {
    sessionManager.currentSessionId
  }

  init(
    messageDisplay: ChatMessageDisplay,
    sessionManager: SessionManager,
    workingDirectory: String?,
    systemInstructions: String? = nil,
    modelIdentifier: String? = nil,
    commandOverride: String? = nil,
    extraArguments: [String] = [],
    environmentOverrides: [String: String] = [:],
    onSessionChange: ((String) -> Void)?,
    onUsageRecorded: ((SessionUsageRecord) -> Void)? = nil,
    onCostUpdate: ((Double) -> Void)? = nil,
    onModelResolved: ((String) -> Void)? = nil
  ) {
    self.messageDisplay = messageDisplay
    self.sessionManager = sessionManager
    self.workingDirectory = workingDirectory
    self.systemInstructions = systemInstructions
    self.modelIdentifier = modelIdentifier
    self.commandOverride = commandOverride
    self.extraArguments = extraArguments
    self.environmentOverrides = environmentOverrides
    self.onSessionChange = onSessionChange
    self.onUsageRecorded = onUsageRecorded
    self.onCostUpdate = onCostUpdate
    self.onModelResolved = onModelResolved
  }

  func markSessionRestored() {
    hasSession = sessionManager.currentSessionId != nil
  }

  func resetSession() {
    hasSession = false
    isCancelled = false
    activeGeneration &+= 1
    terminateActiveProcess()
  }

  func cancel() {
    isCancelled = true
    activeGeneration &+= 1
    terminateActiveProcess()
  }

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    isCancelled = false
    activeGeneration &+= 1
    let generation = activeGeneration

    let resumeSessionId = hasSession ? sessionManager.currentSessionId : nil
    let state = StreamState(
      messageId: messageId,
      firstMessageInSession: firstMessageInSession,
      modelIdentifier: modelIdentifier
    )

    do {
      try await runTurn(
        prompt: prompt,
        resumeSessionId: resumeSessionId,
        state: state,
        generation: generation
      )
    } catch let error as ArnesRunError where resumeSessionId != nil && error.indicatesUnknownSession {
      // The CLI-side transcript is gone (pruned or from another machine).
      // Fall back to a fresh run; the new session id is adopted from its
      // init event, keeping the local history.
      guard activeGeneration == generation, !isCancelled else { return }
      let freshState = StreamState(
        messageId: messageId,
        firstMessageInSession: firstMessageInSession,
        modelIdentifier: modelIdentifier
      )
      try await runTurn(
        prompt: prompt,
        resumeSessionId: nil,
        state: freshState,
        generation: generation
      )
      finishTurn(state: freshState, generation: generation, firstMessageInSession: firstMessageInSession)
      return
    }

    finishTurn(state: state, generation: generation, firstMessageInSession: firstMessageInSession)
  }

  private func finishTurn(state: StreamState, generation: Int, firstMessageInSession: String?) {
    guard activeGeneration == generation, !isCancelled, !Task.isCancelled else { return }

    hasSession = true
    ensureSessionExists(firstMessageInSession: firstMessageInSession)
    finalizeOpenMessages(state: state)

    if state.assistantMessageCount == 0 {
      let fallback = state.resultText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      messageDisplay.addMessage(MessageFactory.assistantMessage(
        id: nextAssistantMessageId(state: state),
        content: fallback.isEmpty ? "(no output)" : fallback,
        isComplete: true
      ))
      state.assistantMessageCount += 1
    }
  }

  // MARK: - Process

  private func runTurn(
    prompt: String,
    resumeSessionId: String?,
    state: StreamState,
    generation: Int
  ) async throws {
    let executable = ArnesExecutableResolver.resolve(commandOverride: commandOverride)
    let arguments = Self.makeArguments(
      executable: executable,
      resumeSessionId: resumeSessionId,
      modelIdentifier: modelIdentifier,
      systemInstructions: systemInstructions,
      extraArguments: extraArguments
    )
    print("[ArnesChatRuntime] Executing: \(executable) \(arguments.joined(separator: " "))")

    let childProcess = Process()
    childProcess.executableURL = URL(fileURLWithPath: executable)
    childProcess.arguments = arguments
    childProcess.environment = ArnesExecutableResolver.environment(overrides: environmentOverrides)
    if let workingDirectory, !workingDirectory.isEmpty {
      childProcess.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
    }

    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    childProcess.standardInput = stdinPipe
    childProcess.standardOutput = stdoutPipe
    childProcess.standardError = stderrPipe

    try childProcess.run()
    activeProcess = childProcess

    // The prompt rides stdin (no task argument), so arbitrarily long
    // prompts never hit argv limits. Written off the main actor — a prompt
    // larger than the pipe buffer would otherwise block the UI.
    let promptData = Data(prompt.utf8)
    Task.detached(priority: .utility) {
      stdinPipe.fileHandleForWriting.write(promptData)
      try? stdinPipe.fileHandleForWriting.close()
    }

    // Collect stderr off the main actor; used only for error reporting.
    let stderrTask = Task.detached(priority: .utility) { () -> String in
      let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8) ?? ""
    }

    do {
      for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
        guard activeGeneration == generation, !isCancelled, !Task.isCancelled else { break }
        process(line: line, state: state)
      }
    } catch {
      // A broken pipe after termination is expected on cancel.
    }

    let status: Int32 = await Task.detached(priority: .utility) { () -> Int32 in
      childProcess.waitUntilExit()
      return childProcess.terminationStatus
    }.value
    if activeProcess === childProcess {
      activeProcess = nil
    }

    guard activeGeneration == generation, !isCancelled else { return }

    // A result envelope means the run spoke the protocol; its stop_reason
    // (and exit codes 2/3 for verifier/stopped-short) are already surfaced
    // through the stream. Only a run that never produced a result is a
    // transport-level failure worth throwing.
    if state.sawResult {
      return
    }

    let stderrOutput = await stderrTask.value
    throw ArnesRunError(
      exitStatus: status,
      stderrOutput: stderrOutput,
      wasResuming: resumeSessionId != nil
    )
  }

  private func terminateActiveProcess() {
    guard let process = activeProcess, process.isRunning else {
      activeProcess = nil
      return
    }
    process.terminate()
    activeProcess = nil
  }

  // MARK: - Arguments

  nonisolated static func makeArguments(
    executable: String,
    resumeSessionId: String?,
    modelIdentifier: String?,
    systemInstructions: String? = nil,
    extraArguments: [String] = []
  ) -> [String] {
    var arguments = ArnesExecutableResolver.argumentsPrefix(forExecutable: executable)
    arguments += ["do", "-", "--yes", "--output-format", "stream-json", "--include-partial"]

    if let resumeSessionId, !resumeSessionId.isEmpty {
      arguments += ["--resume", resumeSessionId]
    } else {
      // Persist the transcript so the next turn can --resume it.
      arguments.append("--session")
    }

    if let model = normalizedModelIdentifier(modelIdentifier) {
      arguments += ["-m", model]
    }

    if let instructions = systemInstructions?.trimmingCharacters(in: .whitespacesAndNewlines),
       !instructions.isEmpty {
      arguments += ["--append-system-prompt", instructions]
    }

    arguments.append(contentsOf: extraArguments)
    return arguments
  }

  /// Empty means "let the provider route" — Arnes defaults to
  /// `openrouter/auto`, so no `-m` flag is sent for it either.
  nonisolated static func normalizedModelIdentifier(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty,
          trimmed != ArnesModelDescriptor.autoIdentifier else {
      return nil
    }
    return trimmed
  }

  // MARK: - Stream processing

  func process(line: String, state: StreamState) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("{"),
          let data = trimmed.data(using: .utf8),
          let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let type = object["type"] as? String else {
      return
    }

    switch type {
    case "init":
      if let sessionId = object["session_id"] as? String, !sessionId.isEmpty {
        updateSessionId(sessionId, firstMessageInSession: state.firstMessageInSession)
      }
      if let model = object["model"] as? String, !model.isEmpty {
        state.servedModelIdentifier = model
        reportResolvedModel(model)
      }

    case "routed":
      // OpenRouter's live routing decision — the concrete model Auto picked,
      // emitted as soon as the provider routes the request.
      if let model = object["model"] as? String, !model.isEmpty {
        state.servedModelIdentifier = model
        reportResolvedModel(model)
      }

    case "text_delta":
      guard let text = object["text"] as? String, !text.isEmpty else { return }
      finishThinkingMessage(state: state)
      appendAssistantDelta(text, state: state)

    case "reasoning_delta":
      guard let text = object["text"] as? String, !text.isEmpty else { return }
      appendThinkingDelta(text, state: state)

    case "assistant":
      guard let text = object["text"] as? String else { return }
      finishThinkingMessage(state: state)
      completeAssistantMessage(text, state: state)

    case "tool_call":
      guard let name = object["name"] as? String else { return }
      finishThinkingMessage(state: state)
      finishStreamingAssistantMessage(state: state)
      let toolUseID = UUID().uuidString
      state.pendingToolUseIDs[name, default: []].append(toolUseID)
      let arguments = object["arguments"] as? [String: Any] ?? [:]

      if name == "update_plan" {
        // Rendered from the plan_updated event that follows (it carries the
        // parsed steps); remember the id so the plan pairs with a result.
        state.planToolUseID = toolUseID
        return
      }
      messageDisplay.addMessage(ArnesMessageMapper.toolUse(
        name: name,
        arguments: arguments,
        toolUseID: toolUseID
      ))

    case "plan_updated":
      guard let steps = object["steps"] as? [[String: Any]] else { return }
      let entries = steps.compactMap { step -> (step: String, status: String)? in
        guard let text = step["step"] as? String else { return nil }
        return (step: text, status: step["status"] as? String ?? "pending")
      }
      guard !entries.isEmpty else { return }
      let markdown = ArnesMessageMapper.planMarkdown(steps: entries)
      let toolUseID = state.planToolUseID ?? UUID().uuidString
      messageDisplay.addMessage(MessageFactory.toolUseMessage(
        toolName: "TodoWrite",
        input: markdown,
        toolInputData: ToolInputData(parameters: ["todos": markdown]),
        toolUseID: toolUseID
      ))
      let done = entries.filter { $0.status == "completed" }.count
      messageDisplay.addMessage(ChatMessage(
        role: .toolResult,
        content: "Plan updated · \(done)/\(entries.count) done",
        messageType: .toolResult,
        toolName: "TodoWrite",
        toolUseID: toolUseID
      ))

    case "tool_result":
      guard let name = object["name"] as? String else { return }
      let toolUseID = dequeueToolUseID(for: name, state: state)
      if name == "update_plan" {
        // The plan card already got its paired result from plan_updated.
        state.planToolUseID = nil
        return
      }
      let preview = object["preview"] as? String ?? ""
      messageDisplay.addMessage(ArnesMessageMapper.toolResult(
        name: name,
        preview: preview,
        toolUseID: toolUseID
      ))

    case "tool_denied":
      guard let name = object["name"] as? String else { return }
      let toolUseID = dequeueToolUseID(for: name, state: state)
      messageDisplay.addMessage(ArnesMessageMapper.toolDenied(
        name: name,
        reason: object["reason"] as? String,
        toolUseID: toolUseID
      ))

    case "subagent_started", "subagent_backgrounded":
      guard let name = object["name"] as? String,
            let id = object["id"] as? String else { return }
      finishThinkingMessage(state: state)
      finishStreamingAssistantMessage(state: state)
      guard !state.displayedSubagentIDs.contains(id) else { return }
      state.displayedSubagentIDs.insert(id)
      let toolUseID = "subagent-\(id)"
      messageDisplay.addMessage(ArnesMessageMapper.subagentToolUse(
        name: name,
        task: object["task"] as? String ?? "",
        model: object["model"] as? String ?? "",
        toolUseID: toolUseID
      ))

    case "subagent_finished":
      guard let name = object["name"] as? String,
            let id = object["id"] as? String else { return }
      messageDisplay.addMessage(ArnesMessageMapper.subagentToolResult(
        name: name,
        steps: object["steps"] as? Int ?? 0,
        toolCalls: object["tool_calls"] as? Int ?? 0,
        costUSD: object["cost_usd"] as? Double ?? 0,
        resultPreview: object["result_preview"] as? String ?? "",
        toolUseID: "subagent-\(id)"
      ))

    case "turn_finished":
      if let turnCost = object["turn_cost_usd"] as? Double {
        state.turnCostUSD = turnCost
      }

    case "result":
      state.sawResult = true
      state.resultText = object["result"] as? String
      recordResult(object, state: state)

    default:
      // routed / retrying / nudged / setting_ignored / content hygiene
      // events are CLI-side progress chatter, not conversation content.
      break
    }
  }

  // MARK: - Assistant text

  private func appendAssistantDelta(_ text: String, state: StreamState) {
    state.assistantBuffer += text

    if let messageId = state.streamingAssistantMessageId {
      messageDisplay.updateMessage(
        id: messageId,
        content: state.assistantBuffer,
        isComplete: false,
        isError: false
      )
    } else {
      let messageId = nextAssistantMessageId(state: state)
      messageDisplay.addMessage(MessageFactory.assistantMessage(
        id: messageId,
        content: state.assistantBuffer,
        isComplete: false
      ))
      state.streamingAssistantMessageId = messageId
      state.assistantMessageCount += 1
    }
  }

  /// The `assistant` event carries the step's authoritative full text —
  /// settle the streamed message with it (or create one when deltas were
  /// not streamed).
  private func completeAssistantMessage(_ text: String, state: StreamState) {
    let content = text.isEmpty ? state.assistantBuffer : text
    guard !content.isEmpty else { return }

    if let messageId = state.streamingAssistantMessageId {
      messageDisplay.updateMessage(
        id: messageId,
        content: content,
        isComplete: true,
        isError: false
      )
      state.streamingAssistantMessageId = nil
      state.assistantBuffer = ""
      return
    }

    messageDisplay.addMessage(MessageFactory.assistantMessage(
      id: nextAssistantMessageId(state: state),
      content: content,
      isComplete: true
    ))
    state.assistantMessageCount += 1
    state.assistantBuffer = ""
  }

  private func finishStreamingAssistantMessage(state: StreamState) {
    guard let messageId = state.streamingAssistantMessageId else { return }
    messageDisplay.updateMessage(
      id: messageId,
      content: state.assistantBuffer,
      isComplete: true,
      isError: false
    )
    state.streamingAssistantMessageId = nil
    state.assistantBuffer = ""
  }

  private func nextAssistantMessageId(state: StreamState) -> UUID {
    if state.assistantMessageCount == 0 {
      return state.messageId
    }
    return UUID()
  }

  // MARK: - Thinking

  private func appendThinkingDelta(_ text: String, state: StreamState) {
    state.thinkingBuffer += text

    if let messageId = state.streamingThinkingMessageId {
      messageDisplay.updateMessage(
        id: messageId,
        content: state.thinkingBuffer,
        isComplete: false,
        isError: false
      )
    } else {
      let messageId = UUID()
      messageDisplay.addMessage(ChatMessage(
        id: messageId,
        role: .thinking,
        content: state.thinkingBuffer,
        isComplete: false,
        messageType: .thinking
      ))
      state.streamingThinkingMessageId = messageId
    }
  }

  private func finishThinkingMessage(state: StreamState) {
    guard let messageId = state.streamingThinkingMessageId else { return }
    messageDisplay.updateMessage(
      id: messageId,
      content: state.thinkingBuffer,
      isComplete: true,
      isError: false
    )
    state.streamingThinkingMessageId = nil
    state.thinkingBuffer = ""
  }

  private func finalizeOpenMessages(state: StreamState) {
    finishThinkingMessage(state: state)
    finishStreamingAssistantMessage(state: state)
  }

  // MARK: - Result / usage

  private func recordResult(_ object: [String: Any], state: StreamState) {
    finalizeOpenMessages(state: state)

    if let sessionId = object["session_id"] as? String, !sessionId.isEmpty {
      updateSessionId(sessionId, firstMessageInSession: state.firstMessageInSession)
    }

    if let isError = object["is_error"] as? Bool, isError {
      let errorText = object["error"] as? String
        ?? object["result"] as? String
        ?? "The arnes run failed."
      messageDisplay.addMessage(ChatMessage(
        role: .toolError,
        content: errorText,
        messageType: .toolError,
        isError: true
      ))
    }

    if let cost = object["cost_usd"] as? Double {
      onCostUpdate?(cost)
    }

    let promptTokens = object["prompt_tokens"] as? Int ?? 0
    let completionTokens = object["completion_tokens"] as? Int ?? 0
    let cachedTokens = object["cached_tokens"] as? Int ?? 0
    if promptTokens > 0 || completionTokens > 0 {
      ensureSessionExists(firstMessageInSession: state.firstMessageInSession)
      let servedModel = (object["routed_models"] as? [String])?.first
        ?? object["model"] as? String
        ?? state.servedModelIdentifier
        ?? state.modelIdentifier
      if let servedModel {
        reportResolvedModel(servedModel)
      }
      onUsageRecorded?(SessionUsageRecord(
        provider: .arnes,
        modelIdentifier: servedModel,
        inputTokens: promptTokens,
        outputTokens: completionTokens,
        cachedInputTokens: cachedTokens
      ))
    }
  }

  /// Surfaces the model the harness actually served. `openrouter/auto` is the
  /// requested routing slug, not a resolution — the UI already shows "Auto".
  private func reportResolvedModel(_ identifier: String) {
    guard identifier != ArnesModelDescriptor.autoIdentifier else { return }
    onModelResolved?(identifier)
  }

  private func dequeueToolUseID(for name: String, state: StreamState) -> String? {
    guard var queue = state.pendingToolUseIDs[name], !queue.isEmpty else { return nil }
    let id = queue.removeFirst()
    state.pendingToolUseIDs[name] = queue
    return id
  }

  // MARK: - Session

  private func updateSessionId(_ sessionId: String, firstMessageInSession: String?) {
    guard !sessionId.isEmpty else { return }

    if sessionManager.currentSessionId == nil {
      sessionManager.startNewSession(
        id: sessionId,
        firstMessage: firstMessageInSession ?? "New conversation",
        workingDirectory: workingDirectory,
        provider: .arnes
      )
      onSessionChange?(sessionId)
    } else if sessionManager.currentSessionId != sessionId {
      sessionManager.updateCurrentSession(id: sessionId)
      onSessionChange?(sessionId)
    }
  }

  private func ensureSessionExists(firstMessageInSession: String?) {
    guard sessionManager.currentSessionId == nil else { return }

    let sessionId = UUID().uuidString
    sessionManager.startNewSession(
      id: sessionId,
      firstMessage: firstMessageInSession ?? "New conversation",
      workingDirectory: workingDirectory,
      provider: .arnes
    )
    onSessionChange?(sessionId)
  }

  final class StreamState {
    let messageId: UUID
    let firstMessageInSession: String?
    let modelIdentifier: String?
    var servedModelIdentifier: String?
    var assistantBuffer = ""
    var streamingAssistantMessageId: UUID?
    var assistantMessageCount = 0
    var thinkingBuffer = ""
    var streamingThinkingMessageId: UUID?
    var pendingToolUseIDs: [String: [String]] = [:]
    var displayedSubagentIDs: Set<String> = []
    var planToolUseID: String?
    var turnCostUSD: Double?
    var sawResult = false
    var resultText: String?

    init(messageId: UUID, firstMessageInSession: String?, modelIdentifier: String? = nil) {
      self.messageId = messageId
      self.firstMessageInSession = firstMessageInSession
      self.modelIdentifier = modelIdentifier
    }
  }
}

struct ArnesRunError: LocalizedError {
  let exitStatus: Int32
  let stderrOutput: String
  let wasResuming: Bool

  var errorDescription: String? {
    let trimmed = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "arnes exited with status \(exitStatus) before producing a result."
    }
    // Keep the tail — usage errors print last.
    let tail = trimmed.split(separator: "\n").suffix(6).joined(separator: "\n")
    return tail
  }

  /// A usage error naming the saved session means the CLI no longer has the
  /// transcript — the caller retries as a fresh run.
  var indicatesUnknownSession: Bool {
    guard wasResuming else { return false }
    let lowered = stderrOutput.lowercased()
    return lowered.contains("session")
      && (lowered.contains("not found") || lowered.contains("unknown") || lowered.contains("no saved"))
  }
}
