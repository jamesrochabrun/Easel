//
//  CodexChatRuntime.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

@MainActor
final class CodexChatRuntime {
  var workingDirectory: String?

  private let messageDisplay: ChatMessageDisplay
  private let sessionManager: SessionManager
  private let onSessionChange: ((String) -> Void)?
  private var hasSession = false
  private var isCancelled = false

  init(
    messageDisplay: ChatMessageDisplay,
    sessionManager: SessionManager,
    workingDirectory: String?,
    onSessionChange: ((String) -> Void)?
  ) {
    self.messageDisplay = messageDisplay
    self.sessionManager = sessionManager
    self.workingDirectory = workingDirectory
    self.onSessionChange = onSessionChange
  }

  func markSessionRestored() {
    hasSession = sessionManager.currentSessionId != nil
  }

  func resetSession() {
    hasSession = false
    isCancelled = false
  }

  func cancel() {
    isCancelled = true
  }

  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws {
    isCancelled = false

    let state = StreamState(messageId: messageId, firstMessageInSession: firstMessageInSession)
    let isFirstTurn = !hasSession
    let options = Self.makeOptions(
      isFirstTurn: isFirstTurn,
      currentSessionId: sessionManager.currentSessionId,
      workingDirectory: workingDirectory
    )
    let client = makeClient()

    let eventStream = AsyncStream<CodexExecEvent>.makeStream()
    let eventTask = Task { @MainActor [weak self, weak state] in
      for await event in eventStream.stream {
        guard let self, let state, !self.isCancelled, !Task.isCancelled else { continue }
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

    guard !isCancelled, !Task.isCancelled else { return }

    hasSession = true
    ensureSessionExists(firstMessageInSession: firstMessageInSession)
    finalizeAssistantMessage(state: state, fallbackOutput: result.stderr)
  }

  private func makeClient() -> CodexExecClient {
    var configuration = CodexExecConfiguration.withNvmSupport()
    configuration.enableDebugLogging = true
    configuration.useLoginShell = true
    configuration.workingDirectory = workingDirectory

    let homeDirectory = NSHomeDirectory()
    let localCodexPath = "\(homeDirectory)/.codex/local/codex"
    if FileManager.default.isExecutableFile(atPath: localCodexPath) {
      configuration.command = localCodexPath
    } else {
      var commandFound = false
      if let nvmPath = NvmPathDetector.detectNvmPath() {
        let nvmCodexPath = "\(nvmPath)/codex"
        if FileManager.default.isExecutableFile(atPath: nvmCodexPath) {
          configuration.command = nvmCodexPath
          commandFound = true
        }
      }
      if !commandFound, let detected = CodexBinaryDetector.detect() {
        configuration.command = detected.path
      }
    }

    configuration.additionalPaths.append(contentsOf: [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDirectory)/.bun/bin",
      "\(homeDirectory)/.deno/bin",
      "\(homeDirectory)/.cargo/bin",
      "\(homeDirectory)/.local/bin",
    ])

    return CodexExecClient(configuration: configuration)
  }

  static func makeOptions(
    isFirstTurn: Bool,
    currentSessionId: String?,
    workingDirectory: String?,
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
