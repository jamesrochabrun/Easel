//
//  CodexChatRuntime.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

@MainActor
final class CodexChatRuntime {
  var workingDirectory: String?
  var developerInstructions: String?
  var modelIdentifier: String?
  /// User-overridden Codex CLI command. Empty/nil means auto-detect.
  var commandOverride: String?
  /// Extra arguments appended to each Codex CLI launch.
  var extraArguments: [String]
  /// Environment variable overrides injected into the Codex CLI process.
  var environmentOverrides: [String: String]

  private let messageDisplay: ChatMessageDisplay
  private let sessionManager: SessionManager
  private let onSessionChange: ((String) -> Void)?
  private var hasSession = false
  private var isCancelled = false
  /// Monotonically increasing token identifying the active turn. Each `send`
  /// captures the current value; `cancel`/`resetSession` (and the next `send`)
  /// bump it. A turn whose token no longer matches must not mutate shared state
  /// — this prevents a still-streaming turn from bleeding into a new session or
  /// workspace after the user switches away mid-generation.
  private(set) var activeGeneration = 0

  init(
    messageDisplay: ChatMessageDisplay,
    sessionManager: SessionManager,
    workingDirectory: String?,
    developerInstructions: String? = nil,
    modelIdentifier: String? = nil,
    commandOverride: String? = nil,
    extraArguments: [String] = [],
    environmentOverrides: [String: String] = [:],
    onSessionChange: ((String) -> Void)?
  ) {
    self.messageDisplay = messageDisplay
    self.sessionManager = sessionManager
    self.workingDirectory = workingDirectory
    self.developerInstructions = developerInstructions
    self.modelIdentifier = modelIdentifier
    self.commandOverride = commandOverride
    self.extraArguments = extraArguments
    self.environmentOverrides = environmentOverrides
    self.onSessionChange = onSessionChange
  }

  func markSessionRestored() {
    hasSession = sessionManager.currentSessionId != nil
  }

  func resetSession() {
    hasSession = false
    isCancelled = false
    activeGeneration &+= 1
  }

  func cancel() {
    isCancelled = true
    activeGeneration &+= 1
  }

  /// Splits a raw shell-style argument string into individual arguments,
  /// honoring single/double quotes and backslash escapes. Mirrors how a shell
  /// tokenizes `--flag "a b"` into `["--flag", "a b"]`.
  nonisolated static func parseArgumentString(_ value: String) -> [String] {
    var arguments: [String] = []
    var current = ""
    var quote: Character?
    var escaping = false
    var hasCurrentArgument = false

    for character in value {
      if escaping {
        current.append(character)
        hasCurrentArgument = true
        escaping = false
        continue
      }

      if character == "\\" {
        escaping = true
        hasCurrentArgument = true
        continue
      }

      if let activeQuote = quote {
        if character == activeQuote {
          quote = nil
        } else {
          current.append(character)
          hasCurrentArgument = true
        }
        continue
      }

      if character == "'" || character == "\"" {
        quote = character
        hasCurrentArgument = true
        continue
      }

      if character.isWhitespace {
        if hasCurrentArgument {
          arguments.append(current)
          current = ""
          hasCurrentArgument = false
        }
        continue
      }

      current.append(character)
      hasCurrentArgument = true
    }

    if escaping {
      current.append("\\")
    }
    if hasCurrentArgument {
      arguments.append(current)
    }
    return arguments
  }

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    isCancelled = false
    activeGeneration &+= 1
    let generation = activeGeneration

    let state = StreamState(messageId: messageId, firstMessageInSession: firstMessageInSession)
    let isFirstTurn = !hasSession
    let options = Self.makeOptions(
      isFirstTurn: isFirstTurn,
      currentSessionId: sessionManager.currentSessionId,
      workingDirectory: workingDirectory,
      developerInstructions: developerInstructions,
      modelIdentifier: modelIdentifier,
      extraArguments: extraArguments
    )
    print(Self.debugCommandDescription(options: options))
    let client = makeClient()

    let eventStream = AsyncStream<CodexExecEvent>.makeStream()
    let eventTask = Task { @MainActor [weak self, weak state] in
      for await event in eventStream.stream {
        guard let self, let state, !Task.isCancelled,
              self.activeGeneration == generation, !self.isCancelled else { continue }
        self.process(event, state: state)
      }
    }

    let result: CodexExecResult
    do {
      result = try await client.run(prompt: prompt, options: options) { event in
        eventStream.continuation.yield(event)
      }
    } catch {
      eventStream.continuation.finish()
      await eventTask.value
      throw error
    }

    eventStream.continuation.finish()
    await eventTask.value

    // Bail if this turn was superseded (workspace/session switched) or cancelled
    // — otherwise it would persist its session and finalize into the wrong chat.
    guard activeGeneration == generation, !isCancelled, !Task.isCancelled else { return }

    hasSession = true
    ensureSessionExists(firstMessageInSession: firstMessageInSession)
    finalizeAssistantMessage(state: state, fallbackOutput: result.stderr)
  }

  private func makeClient() -> CodexExecClient {
    var configuration = CodexExecConfiguration.withNvmSupport()
    configuration.enableDebugLogging = true
    configuration.useLoginShell = true
    configuration.workingDirectory = workingDirectory

    let resolver = CodexCommandResolver()
    if let resolvedCommand = resolver.resolve(commandOverride: commandOverride) {
      configuration.command = resolvedCommand.path
    }

    configuration.additionalPaths.append(contentsOf: resolver.searchPathDirectories())

    // Apply user-provided environment overrides last so they win.
    for (key, value) in environmentOverrides {
      let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedKey.isEmpty else { continue }
      configuration.environment[trimmedKey] = value
    }

    return CodexExecClient(configuration: configuration)
  }

  static func makeOptions(
    isFirstTurn: Bool,
    currentSessionId: String?,
    workingDirectory: String?,
    developerInstructions: String? = nil,
    modelIdentifier: String? = nil,
    extraArguments: [String] = [],
    configOverrides: [String: String] = CodexUserConfigCompatibility.compatibleConfigOverrides()
  ) -> CodexExecOptions {
    var options = CodexExecOptions()
    options.promptViaStdin = true
    options.timeout = 10_000
    options.skipGitRepoCheck = true
    options.jsonEvents = true

    for (key, value) in configOverrides {
      options.configOverrides[key] = value
    }

    // User-configured extra arguments, appended to every launch.
    if !extraArguments.isEmpty {
      options.extraFlags.append(contentsOf: extraArguments)
    }

    if let developerInstructions = tomlString(developerInstructions) {
      options.configOverrides["developer_instructions"] = developerInstructions
    }

    if let model = normalizedModelIdentifier(modelIdentifier) {
      options.model = model
    }

    if isFirstTurn {
      options.sandbox = .workspaceWrite
      options.approval = .never
      options.fullAuto = true
      if let workingDirectory, !workingDirectory.isEmpty {
        options.changeDirectory = workingDirectory
      }
    } else if let sessionId = currentSessionId {
      options.resumeSessionId = sessionId
    } else {
      options.resumeLastSession = true
    }

    return options
  }

  static func debugCommandDescription(options: CodexExecOptions) -> String {
    var parts = ["codex", "exec"]

    if let sessionId = options.resumeSessionId {
      parts.append("resume")
      parts.append(shellQuoted(sessionId))
    } else if options.resumeLastSession {
      parts.append("resume")
      parts.append("--last")
    }

    if let model = options.model {
      parts.append("--model")
      parts.append(shellQuoted(model))
    }

    if let approval = options.approval {
      parts.append("-c")
      parts.append(shellQuoted("approval=\(approval.rawValue)"))
    }

    if let sandbox = options.sandbox {
      parts.append("--sandbox")
      parts.append(sandbox.rawValue)
    }

    if options.fullAuto {
      parts.append("--full-auto")
    }

    if let changeDirectory = options.changeDirectory {
      parts.append("--cd")
      parts.append(shellQuoted(changeDirectory))
    }

    if options.skipGitRepoCheck {
      parts.append("--skip-git-repo-check")
    }

    if options.jsonEvents {
      parts.append("--json")
    }

    for key in options.configOverrides.keys.sorted() {
      guard let value = options.configOverrides[key] else { continue }
      parts.append("-c")
      parts.append(shellQuoted("\(key)=\(value)"))
    }

    if options.promptViaStdin {
      parts.append("-")
    }

    return "[CodexChatRuntime] Executing: \(parts.joined(separator: " "))"
  }

  private static func normalizedModelIdentifier(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  private static func shellQuoted(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
  }

  private static func tomlString(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let escaped = trimmed
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")

    return "\"\(escaped)\""
  }

  func process(_ event: CodexExecEvent, state: StreamState) {
    switch event {
    case .jsonEvent(let json):
      process(json, state: state)

    case .stdout(let line):
      appendAssistantText(line, state: state)

    case .stderr(let line):
      if hasSession, let displayLine = CodexStderrParser.displayLine(from: line) {
        appendAssistantText(displayLine, state: state)
      }
    }
  }

  func process(_ event: CodexJSONEvent, state: StreamState) {
    if event.type == "thread.started", let threadId = event.threadId {
      updateSessionId(threadId, firstMessageInSession: state.firstMessageInSession)
      return
    }

    if let error = event.error, !error.isEmpty {
      messageDisplay.addMessage(ChatMessage(
        role: .toolError,
        content: error,
        messageType: .toolError,
        isError: true
      ))
      return
    }

    guard let item = event.item else {
      if let text = event.text, !text.isEmpty {
        appendAssistantText(text, state: state)
      }
      return
    }

    switch (event.type, item.type) {
    case ("item.completed", "agent_message"):
      if let text = item.text {
        addCompletedAssistantMessage(text, state: state)
      }

    case ("item.completed", "reasoning"):
      if let text = item.text, !text.isEmpty {
        messageDisplay.addMessage(MessageFactory.thinkingMessage(content: text))
      }

    case ("item.started", "command_execution"):
      if let command = item.command {
        rememberCommand(command, for: item.id, state: state)
      }
      if let command = item.command,
         CodexMessageMapper.isDisplayableCommand(command),
         !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.commandToolUse(command: command, itemID: item.id))
      }

    case ("item.completed", "command_execution"):
      if let command = item.command {
        rememberCommand(command, for: item.id, state: state)
      }
      let command = item.command ?? rememberedCommand(for: item.id, state: state)
      // Skip no-op executions with an empty script — they carry no action to show.
      guard let command, CodexMessageMapper.isDisplayableCommand(command) else {
        break
      }
      if !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.commandToolUse(command: command, itemID: item.id))
      }
      messageDisplay.addMessage(CodexMessageMapper.commandToolResult(
        output: item.aggregatedOutput,
        exitCode: item.exitCode,
        itemID: item.id
      ))

    case ("item.started", "mcp_tool_call"):
      if !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.mcpToolUse(
          toolName: item.toolName,
          arguments: item.toolArguments,
          itemID: item.id
        ))
      }

    case ("item.completed", "mcp_tool_call"):
      if !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.mcpToolUse(
          toolName: item.toolName,
          arguments: item.toolArguments,
          itemID: item.id
        ))
      }
      messageDisplay.addMessage(CodexMessageMapper.mcpToolResult(
        toolName: item.toolName,
        result: item.toolResult,
        itemID: item.id
      ))

    case ("item.started", "web_search"):
      if !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.webSearchToolUse(query: item.query, itemID: item.id))
      }

    case ("item.completed", "web_search"):
      if !hasItemDisplayed(item.id, state: state) {
        markItemDisplayed(item.id, state: state)
        messageDisplay.addMessage(CodexMessageMapper.webSearchToolUse(query: item.query, itemID: item.id))
      }
      messageDisplay.addMessage(CodexMessageMapper.webSearchToolResult(
        resultCount: item.results?.count ?? 0,
        itemID: item.id
      ))

    case ("item.completed", "file_change"):
      if let toolUse = CodexMessageMapper.fileChangeToolUse(
        changes: item.changes,
        legacyPath: item.filePath,
        itemID: item.id
      ) {
        messageDisplay.addMessage(toolUse)
      }
      if let toolResult = CodexMessageMapper.fileChangeToolResult(
        changes: item.changes,
        legacyPath: item.filePath,
        itemID: item.id
      ) {
        messageDisplay.addMessage(toolResult)
      }

    case ("item.completed", "todo_list"):
      if let toolUse = CodexMessageMapper.todoToolUse(items: item.items, itemID: item.id) {
        messageDisplay.addMessage(toolUse)
      }
      if let toolResult = CodexMessageMapper.todoToolResult(items: item.items, itemID: item.id) {
        messageDisplay.addMessage(toolResult)
      }

    default:
      break
    }
  }

  private func appendAssistantText(_ text: String, state: StreamState) {
    let cleaned = cleanOutput(text)
    guard !cleaned.isEmpty else { return }

    if state.assistantBuffer.isEmpty {
      state.assistantBuffer = cleaned
    } else {
      state.assistantBuffer += "\n\(cleaned)"
    }

    if state.assistantMessageCreated {
      guard let messageId = state.streamingAssistantMessageId else { return }
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
      state.assistantMessageCreated = true
      state.streamingAssistantMessageId = messageId
      state.assistantMessageCount += 1
    }
  }

  private func addCompletedAssistantMessage(_ text: String, state: StreamState) {
    let cleaned = cleanOutput(text)
    guard !cleaned.isEmpty else { return }

    finishStreamingAssistantMessage(state: state)

    let messageId = nextAssistantMessageId(state: state)
    messageDisplay.addMessage(MessageFactory.assistantMessage(
      id: messageId,
      content: cleaned,
      isComplete: true
    ))
    state.assistantMessageCount += 1
  }

  private func finalizeAssistantMessage(state: StreamState, fallbackOutput: String) {
    if state.assistantMessageCreated {
      finishStreamingAssistantMessage(state: state)
      return
    }

    guard state.assistantMessageCount == 0 else {
      return
    }

    let fallback = cleanOutput(fallbackOutput)
    messageDisplay.addMessage(MessageFactory.assistantMessage(
      id: nextAssistantMessageId(state: state),
      content: fallback.isEmpty ? "(no output)" : fallback,
      isComplete: true
    ))
    state.assistantMessageCount += 1
  }

  private func finishStreamingAssistantMessage(state: StreamState) {
    guard state.assistantMessageCreated,
          let messageId = state.streamingAssistantMessageId else {
      return
    }

    messageDisplay.updateMessage(
      id: messageId,
      content: state.assistantBuffer.isEmpty ? "(no output)" : state.assistantBuffer,
      isComplete: true,
      isError: false
    )
    state.assistantBuffer = ""
    state.assistantMessageCreated = false
    state.streamingAssistantMessageId = nil
  }

  private func nextAssistantMessageId(state: StreamState) -> UUID {
    if state.assistantMessageCount == 0 {
      return state.messageId
    }

    return UUID()
  }

  private func updateSessionId(_ sessionId: String, firstMessageInSession: String?) {
    guard !sessionId.isEmpty else { return }

    if sessionManager.currentSessionId == nil {
      sessionManager.startNewSession(
        id: sessionId,
        firstMessage: firstMessageInSession ?? "New conversation",
        workingDirectory: workingDirectory
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
      workingDirectory: workingDirectory
    )
    onSessionChange?(sessionId)
  }

  private func markItemDisplayed(_ id: String?, state: StreamState) {
    guard let id else { return }
    state.displayedItemIds.insert(id)
  }

  private func hasItemDisplayed(_ id: String?, state: StreamState) -> Bool {
    guard let id else { return false }
    return state.displayedItemIds.contains(id)
  }

  private func rememberCommand(_ command: String, for id: String?, state: StreamState) {
    guard let id, !id.isEmpty else { return }
    state.commandByItemId[id] = command
  }

  private func rememberedCommand(for id: String?, state: StreamState) -> String? {
    guard let id else { return nil }
    return state.commandByItemId[id]
  }

  private func cleanOutput(_ text: String) -> String {
    text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { line in
        let lower = line.lowercased()
        if lower.contains("openai codex") { return false }
        if lower.contains("workdir:") { return false }
        if lower.contains("model:") { return false }
        if lower.contains("provider:") { return false }
        if lower.contains("approval:") { return false }
        if lower.contains("sandbox:") { return false }
        if lower.trimmingCharacters(in: .whitespacesAndNewlines) == "--------" { return false }
        return true
      }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  final class StreamState {
    let messageId: UUID
    let firstMessageInSession: String?
    var assistantBuffer = ""
    var assistantMessageCreated = false
    var streamingAssistantMessageId: UUID?
    var assistantMessageCount = 0
    var displayedItemIds: Set<String> = []
    var commandByItemId: [String: String] = [:]

    init(messageId: UUID, firstMessageInSession: String?) {
      self.messageId = messageId
      self.firstMessageInSession = firstMessageInSession
    }
  }
}

private enum CodexStderrParser {
  static func displayLine(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !shouldFilter(trimmed) else { return nil }

    if trimmed == "thinking" || trimmed == "exec" || trimmed == "file update" {
      return nil
    }

    if trimmed.contains("succeeded in") || trimmed.contains("failed in") {
      return "$ \(CodexMessageMapper.shortenCommand(trimmed))"
    }

    return nil
  }

  private static func shouldFilter(_ line: String) -> Bool {
    let lower = line.lowercased()
    if lower.contains("openai codex") { return true }
    if lower.contains("workdir:") { return true }
    if lower.contains("model:") { return true }
    if lower.contains("provider:") { return true }
    if lower.contains("approval:") { return true }
    if lower.contains("sandbox:") { return true }
    if lower.contains("reasoning effort") { return true }
    if lower.contains("reasoning summaries") { return true }
    if lower.contains("session id:") { return true }
    if lower.contains("mcp startup") { return true }
    if line == "user" || line == "assistant" { return true }
    return false
  }
}
