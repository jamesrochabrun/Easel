//
//  ChatViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import os.log
import CCCustomPermissionService
import CCCustomPermissionServiceInterface

@Observable
@MainActor
public final class ChatViewModel {
  
  // MARK: - Dependencies
  
  // Problem, row is not collapsing on deny /approve
  
  /// The Claude API client for sending messages and receiving responses from Claude
  var claudeClient: ClaudeCode
  
  /// Manages chat sessions including creation, selection, and lifecycle
  let sessionManager: SessionManager
  
  /// Protocol for persisting session data to disk (messages, metadata)
  let sessionStorage: SessionStorageProtocol
  
  /// Stores application settings like project paths and session-specific configurations
  let settingsStorage: SettingsStorage
  
  /// Global user preferences including allowed tools, max turns, and system prompts
  let globalPreferences: GlobalPreferencesStorage
  
  /// Service for handling custom tool permission requests and user approvals
  var customPermissionService: CustomPermissionService

  /// Tracks tools discovered during runtime for preference reconciliation.
  let mcpToolsDiscovery: MCPToolsDiscoveryService

  private let debugLogger: ClaudeCodeLogger
  
  /// Optional callback invoked when session changes, used for external state synchronization
  private let onSessionChange: ((String) -> Void)?

  /// Optional callback invoked when a session usage total changes.
  private let onSessionUsageChange: ((String) -> Void)?

  /// Optional callback invoked when a user message is sent, used for external logging
  private let onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)?

  /// Optional hidden context supplied by an embedding app for every outgoing turn.
  @ObservationIgnored public var runtimeHiddenContextProvider: (() -> String?)?

  /// Optional hidden context supplied by an embedding app when runtime context is omitted.
  @ObservationIgnored public var outgoingHiddenContextProvider: (() -> String?)?

  /// Controls whether this view model should manage sessions (load, save, switch, etc.)
  /// Set to false when using ChatScreen directly without RootView to avoid unnecessary session operations
  public let shouldManageSessions: Bool

  /// Optional system prompt prefix that gets prepended to the additional system prompt
  private let systemPromptPrefix: String?

  /// Optional Codex developer instructions prefix. Falls back to systemPromptPrefix when nil.
  private let codexDeveloperInstructionsPrefix: String?

  @ObservationIgnored private lazy var streamProcessor: StreamProcessor = {
    let processor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      globalPreferences: globalPreferences,
      mcpToolsDiscovery: mcpToolsDiscovery,
      logger: debugLogger,
      onSessionChange: { [weak self] sessionId in
        self?.handleRuntimeSessionChange(sessionId)
      },
      getCurrentWorkingDirectory: { [weak self] in
        self?.claudeClient.configuration.workingDirectory
      }
    )

    processor.setParentViewModel { [weak self] in
      self
    }

    return processor
  }()
  private let messageStore = MessageStore()
  @ObservationIgnored private var codexRuntime: CodexChatRuntime?
  @ObservationIgnored private var claudeRuntime: ClaudeChatRuntime?
  @ObservationIgnored private var runtimeTask: Task<Void, Never>?
  private var firstMessageInSession: String?
  private var loadingSessionIdentity: LoadingSessionIdentity?
  
  // Session isolation: track if we're in the middle of switching sessions
  private var isSwitchingSession = false
  
  // Stream cancellation: track if user cancelled the current stream
  private var isCancelled = false
  
  // Track expansion states for each message to persist across view recreations
  var messageExpansionStates: [UUID: Bool] = [:]

  // Plan approval is now handled inline via InlinePlanApprovalView

  /// Sessions loading state
  public var isLoadingSessions: Bool {
    sessionManager.isLoadingSessions
  }
  
  /// Sessions error state
  public var sessionsError: Error? {
    sessionManager.sessionsError
  }
  
  private let logger = Logger(subsystem: "com.yourcompany.ClaudeChat", category: "ChatViewModel")
  private var currentMessageId: UUID?
  
  // MARK: - Published Properties

  /// All messages in the conversation
  public var messages: [ChatMessage] {
    messageStore.messages
  }
  
  /// All available sessions
  var sessions: [StoredSession] {
    sessionManager.sessions
  }
  
  /// Current session ID
  var currentSessionId: String? {
    sessionManager.currentSessionId
  }
  
  /// Active session ID (includes pending session during streaming)
  /// This returns the session ID that Claude is actively using, which may be
  /// different from currentSessionId during streaming operations
  var activeSessionId: String? {
    switch activeProvider {
    case .codex:
      return codexRuntime?.activeSessionId ?? sessionManager.currentSessionId
    case .claude:
      return claudeRuntime?.activeSessionId ?? streamProcessor.activeSessionId
    }
  }

  public private(set) var activeProvider: ChatProvider = .codex

  /// Returns all messages currently in memory
  public func getCurrentMessages() -> [ChatMessage] {
    messageStore.getAllMessages()
  }
  
  /// Loading state
  public private(set) var isLoading: Bool = false
  var isCurrentSessionLoading: Bool {
    guard isLoading,
          let loadingSessionIdentity else {
      return false
    }

    return loadingSessionIdentity.matches(currentSessionIdentity)
  }
  
  /// Error state with detailed information
  public var errorInfo: ErrorInfo?

  /// Error queue for multiple errors
  public var errorQueue: [ErrorInfo] = []

  /// Last error for debug reporting (private, captured when error occurs)
  private var lastError: Error?
  
  /// Current project path (observable)
  public var projectPath: String = ""
  
  /// Streaming metrics
  public private(set) var streamingStartTime: Date?
  public private(set) var currentInputTokens: Int = 0
  public private(set) var currentOutputTokens: Int = 0
  public private(set) var currentCostUSD: Double = 0.0
  public private(set) var currentSessionUsageSummary: SessionUsageSummary = .zero
  
  /// Tracks whether a session has started (first message sent)
  public private(set) var hasSessionStarted: Bool = false

  /// Current permission mode for this chat session (runtime state only, not persisted)
  public var permissionMode: ClaudeCodeSDK.PermissionMode = .default

  /// Check if debug logging is enabled from the Claude client configuration
  var isDebugEnabled: Bool {
    claudeClient.configuration.enableDebugLogging
  }

  /// Returns a terminal command that can be copied and pasted to reproduce the last execution
  var terminalReproductionCommand: String? {
    guard let commandInfo = claudeClient.lastExecutedCommandInfo else {
      return nil
    }

    var parts: [String] = []

    // Add working directory change if present
    if let workingDir = commandInfo.workingDirectory {
      let escapedPath = workingDir
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      parts.append("cd \"\(escapedPath)\"")
    }

    // Add stdin content if present using HEREDOC for reliable multiline handling
    if let stdin = commandInfo.stdinContent, !stdin.isEmpty {
      // Use HEREDOC to avoid escaping issues with newlines and special characters
      let heredocCommand = """
cat <<'EOF' | \(commandInfo.commandString)
\(stdin)
EOF
"""
      parts.append(heredocCommand)
    } else {
      parts.append(commandInfo.commandString)
    }

    return parts.joined(separator: " && ")
  }

  /// Generates MCP configuration diagnostics for debug reporting
  private func generateMCPDiagnostics() -> String {
    var diagnostics = "\nMCP CONFIGURATION:"

    // Check MCP config file
    let configPath = globalPreferences.mcpConfigPath
    diagnostics += "\nConfig File: \(configPath)"

    let configExists = FileManager.default.fileExists(atPath: configPath)

    // Try to load and validate config
    let mcpManager = MCPConfigurationManager()
    let configValid = configExists && !mcpManager.configuration.mcpServers.isEmpty

    if !configExists {
      diagnostics += "\nConfig Status: ✗ Not found"
    } else if configValid {
      diagnostics += "\nConfig Status: ✓ Exists and valid"
      let serverNames = mcpManager.configuration.mcpServers.keys.sorted().joined(separator: ", ")
      diagnostics += "\nConfigured Servers: \(mcpManager.configuration.mcpServers.count) (\(serverNames))"
    } else {
      diagnostics += "\nConfig Status: ✗ Exists but empty or invalid"
    }

    // Check approval server binary
    diagnostics += "\n\nAPPROVAL SERVER:"

    let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil)
    let binaryExists = bundlePath != nil && FileManager.default.fileExists(atPath: bundlePath!)

    if let path = bundlePath {
      diagnostics += "\nBinary Path: \(path)"
      diagnostics += "\nBinary Status: \(binaryExists ? "✓ Exists" : "✗ Not found")"
    } else {
      diagnostics += "\nBinary Path: Not in bundle"
      diagnostics += "\nBinary Status: ✗ Not found"
    }

    // Check if approval server is configured in MCP
    if let approvalServer = mcpManager.configuration.mcpServers["approval_server"] {
      diagnostics += "\nConfigured in MCP: ✓ Yes"
      diagnostics += "\nConfigured Path: \(approvalServer.command)"

      // Check if configured path matches bundled path
      if let bundled = bundlePath {
        if approvalServer.command == bundled {
          diagnostics += "\nPath Match: ✓ Matches bundled binary"
        } else {
          diagnostics += "\nPath Match: ✗ Mismatch"
          diagnostics += "\n  Expected (bundled): \(bundled)"
          diagnostics += "\n  Actual (configured): \(approvalServer.command)"
        }
      }
    } else {
      diagnostics += "\nConfigured in MCP: ✗ No"
      if binaryExists {
        diagnostics += "\n⚠️  Binary exists but not configured - run 'Repair' in settings"
      }
    }

    return diagnostics
  }

  /// Returns a complete debug report with all command execution details
  var fullDebugReport: String? {
    guard let commandInfo = claudeClient.lastExecutedCommandInfo else {
      return nil
    }

    // Detect the actual executable path
    let commandName = commandInfo.commandString.components(separatedBy: " ").first ?? ""
    let resolvedExecutable = TerminalLauncher.findClaudeExecutable(
      command: commandName,
      additionalPaths: claudeClient.configuration.additionalPaths
    )

    var report = """
    === CLAUDE CODE DEBUG REPORT ===

    TERMINAL REPRODUCTION COMMAND:
    \(terminalReproductionCommand ?? "N/A")

    COMMAND DETAILS:
    Command: \(commandInfo.commandString)
    Resolved Executable: \(resolvedExecutable ?? "Not found - check PATH and shell aliases")
    Working Directory: \(commandInfo.workingDirectory ?? "None")
    Stdin Content: \(commandInfo.stdinContent ?? "None")
    Executed At: \(commandInfo.executedAt)
    Method: \(commandInfo.method)
    Output Format: \(commandInfo.outputFormat)

    SHELL CONFIGURATION:
    Shell Executable: \(commandInfo.shellExecutable)
    Shell Arguments: \(commandInfo.shellArguments.joined(separator: " "))

    ENVIRONMENT:
    PATH:
    """

    // Add PATH directories
    let pathDirs = commandInfo.pathEnvironment.split(separator: ":")
    for dir in pathDirs {
      report += "\n  - \(dir)"
    }

    report += "\n\nEnvironment Variables: \(commandInfo.environment.count) set"

    // Add some key environment variables if present
    let keyVars = ["NODE_ENV", "HOME", "USER", "SHELL"]
    var foundVars: [String] = []
    for key in keyVars {
      if let value = commandInfo.environment[key] {
        foundVars.append("\(key)=\(value)")
      }
    }
    if !foundVars.isEmpty {
      report += "\nKey Variables:\n  " + foundVars.joined(separator: "\n  ")
    }

    // Add MCP diagnostics
    report += "\n"
    report += generateMCPDiagnostics()

    // Add error information if available
    if let error = lastError {
      report += "\n\nLAST ERROR:"
      report += "\nError Type: \(type(of: error))"
      report += "\nError Message: \(error.localizedDescription)"

      // Extract stderr from ClaudeCodeError if available
      if let claudeError = error as? ClaudeCodeError {
        switch claudeError {
        case .processLaunchFailed(let message), .executionFailed(let message):
          report += "\n\nSUBPROCESS STDERR/OUTPUT:"
          report += "\n\(message)"
        case .invalidOutput(let message):
          report += "\nInvalid Output: \(message)"
        default:
          break
        }
      }

      // Add error info context if available
      if let errorInfo = errorInfo {
        report += "\n\nERROR CONTEXT:"
        report += "\nSeverity: \(errorInfo.severity.displayName)"
        report += "\nOperation: \(errorInfo.operation.displayName)"
        report += "\nContext: \(errorInfo.context)"
        if let suggestion = errorInfo.recoverySuggestion {
          report += "\nRecovery Suggestion: \(suggestion)"
        }
      }
    }

    report += "\n\n=== END DEBUG REPORT ==="

    return report
  }


  // MARK: - Initialization
  
  /// Creates a new ChatViewModel instance.
  /// - Parameters:
  ///   - claudeClient: The Claude client for API communication
  ///   - sessionStorage: Storage protocol for managing sessions
  ///   - settingsStorage: Storage for application settings
  ///   - globalPreferences: Global preferences storage
  ///   - customPermissionService: Service for custom permission management
  ///   - systemPromptPrefix: Optional prefix to prepend to the additional system prompt
  ///   - shouldManageSessions: Whether to manage sessions (load, save, switch). Default is true for backward compatibility.
  ///                           Set to false when using ChatScreen directly without session management needs.
  ///   - onSessionChange: Optional callback when session changes
  /// Convenience initializer for simple integration (uses defaults)
  public convenience init() {
    // Create Claude Code client with default configuration
    // This will use the Claude CLI as a subprocess - no API key needed
    let claudeClient = (try? ClaudeCodeClient()) ?? (try! ClaudeCodeClient(configuration: .default))
    let sessionStorage = NoOpSessionStorage()
    let settingsStorage = SettingsStorageManager()
    let logger = ClaudeCodeLogger()
    let globalPreferences = GlobalPreferencesStorage(logger: logger)
    let permissionService = DefaultCustomPermissionService()

    self.init(
      claudeClient: claudeClient,
      sessionStorage: sessionStorage,
      settingsStorage: settingsStorage,
      globalPreferences: globalPreferences,
      customPermissionService: permissionService,
      mcpToolsDiscovery: MCPToolsDiscoveryService(),
      logger: logger,
      systemPromptPrefix: nil,
      codexDeveloperInstructionsPrefix: nil,
      shouldManageSessions: false,
      onSessionChange: nil,
      onSessionUsageChange: nil,
      onUserMessageSent: nil
    )
  }

  public init(
    claudeClient: ClaudeCode,
    sessionStorage: SessionStorageProtocol,
    settingsStorage: SettingsStorage,
    globalPreferences: GlobalPreferencesStorage,
    customPermissionService: CustomPermissionService,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger(),
    systemPromptPrefix: String? = nil,
    codexDeveloperInstructionsPrefix: String? = nil,
    shouldManageSessions: Bool = true,
    onSessionChange: ((String) -> Void)? = nil,
    onSessionUsageChange: ((String) -> Void)? = nil,
    onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)? = nil)
  {
    self.claudeClient = claudeClient
    self.sessionStorage = sessionStorage
    self.settingsStorage = settingsStorage
    self.globalPreferences = globalPreferences
    self.customPermissionService = customPermissionService
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.debugLogger = logger
    self.systemPromptPrefix = systemPromptPrefix
    self.codexDeveloperInstructionsPrefix = codexDeveloperInstructionsPrefix
    self.shouldManageSessions = shouldManageSessions
    self.onSessionChange = onSessionChange
    self.onSessionUsageChange = onSessionUsageChange
    self.onUserMessageSent = onUserMessageSent
    self.activeProvider = globalPreferences.chatProvider.supportedProvider
    self.sessionManager = SessionManager(sessionStorage: sessionStorage, logger: logger)

    if globalPreferences.chatProvider != activeProvider {
      globalPreferences.chatProvider = activeProvider
    }

    // Set up error handler for SessionManager after all properties are initialized
    self.sessionManager.setErrorHandler { [weak self] error, operation in
      self?.handleError(error, operation: operation)
    }

    // Wire up approval timeout callback
    self.customPermissionService.onConversationShouldPause = { [weak self] toolUseId, _ in
      Task { @MainActor in
        await self?.handleApprovalTimeout(toolUseId: toolUseId)
      }
    }

    // Wire up resume after timeout callback
    self.customPermissionService.onResumeAfterTimeout = { [weak self] approved, toolName in
      Task { @MainActor in
        await self?.resumeAfterApprovalTimeout(approved: approved, toolName: toolName)
      }
    }

    // Only load sessions if we're managing them (e.g., when used with RootView)
    // Skip loading when using ChatScreen directly to avoid wasteful operations
    if shouldManageSessions {
      Task {
        await loadSessions()
      }
    }

    // Initialize project path
    self.projectPath = settingsStorage.projectPath
  }
  
  /// Updates the project path when settings change
  public func refreshProjectPath() {
    projectPath = settingsStorage.projectPath
  }

  /// Updates the Claude command when global preferences change
  public func updateClaudeCommand(from globalPreferences: GlobalPreferencesStorage) {
    claudeClient.configuration.command = globalPreferences.claudeCommand

    // Add manual Claude path if specified
    if !globalPreferences.claudePath.isEmpty {
      // Validate that the file exists
      if FileManager.default.fileExists(atPath: globalPreferences.claudePath) {
        let url = URL(fileURLWithPath: globalPreferences.claudePath)
        let directory = url.deletingLastPathComponent().path

        // Insert at the beginning for highest priority (if not already present)
        if !claudeClient.configuration.additionalPaths.contains(directory) {
          claudeClient.configuration.additionalPaths.insert(directory, at: 0)
        }
      }
    }
  }

  public func switchProvider(to provider: ChatProvider) {
    let provider = provider.supportedProvider
    guard activeProvider != provider else {
      if globalPreferences.chatProvider != provider {
        globalPreferences.chatProvider = provider
      }
      return
    }

    let currentDirectory = projectPath
    persistCurrentMessagesInBackground()
    cancelRequest()
    clearConversation(resetProviderToDefault: false)
    activeProvider = provider
    globalPreferences.chatProvider = provider

    if !currentDirectory.isEmpty {
      setWorkingDirectory(currentDirectory)
    }
  }

  private func ensureProviderMatchesPreferencesForNewSession() {
    guard sessionManager.currentSessionId == nil else { return }

    let selectedProvider = globalPreferences.chatProvider.supportedProvider
    guard activeProvider != selectedProvider else {
      if globalPreferences.chatProvider != selectedProvider {
        globalPreferences.chatProvider = selectedProvider
      }
      return
    }

    let currentDirectory = projectPath
    clearConversation()
    activeProvider = selectedProvider
    globalPreferences.chatProvider = selectedProvider

    if !currentDirectory.isEmpty {
      setWorkingDirectory(currentDirectory)
    }
  }

  private func setActiveProvider(_ provider: ChatProvider) {
    activeProvider = provider.supportedProvider
  }

  private var currentSessionIdentity: LoadingSessionIdentity {
    LoadingSessionIdentity(
      sessionId: sessionManager.currentSessionId,
      workingDirectory: normalizedWorkingDirectory(claudeClient.configuration.workingDirectory ?? projectPath)
    )
  }

  private func beginLoadingState() {
    isLoading = true
    loadingSessionIdentity = currentSessionIdentity
    streamingStartTime = .now
    currentInputTokens = 0
    currentOutputTokens = 0
    currentCostUSD = 0.0
  }

  private func endLoadingState() {
    isLoading = false
    streamingStartTime = nil
    loadingSessionIdentity = nil
  }

  private func handleSessionChange(_ sessionId: String) {
    onSessionChange?(sessionId)
  }

  private func handleRuntimeSessionChange(_ sessionId: String) {
    updateLoadingSessionIdentityIfNeeded(sessionId: sessionId)
    handleSessionChange(sessionId)
  }

  private func updateLoadingSessionIdentityIfNeeded(sessionId: String) {
    guard isLoading,
          let loadingSessionIdentity,
          loadingSessionIdentity.sessionId == nil,
          loadingSessionIdentity.workingDirectory == currentSessionIdentity.workingDirectory else {
      return
    }

    self.loadingSessionIdentity = loadingSessionIdentity.replacingSessionId(sessionId)
  }

  private func normalizedWorkingDirectory(_ directory: String?) -> String? {
    let trimmedDirectory = directory?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedDirectory?.isEmpty == false ? trimmedDirectory : nil
  }
  
  // MARK: - Public Methods
  /// Retries the last user message with all its original data
  public func retryLastMessage() {
    guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

    // Extract the original data from the stored message
    let text = lastUserMessage.content
    let codeSelections = lastUserMessage.codeSelections

    // Convert stored attachments back to FileAttachments
    let attachments: [FileAttachment]? = lastUserMessage.attachments?.compactMap { stored in
      // Create FileAttachment from the stored file path
      let fileURL = URL(fileURLWithPath: stored.filePath)
      let attachment = FileAttachment(url: fileURL)
      // Set the state to ready since we're just referencing the file path
      attachment.state = .ready(content: .image(path: stored.filePath, base64URL: "", thumbnailBase64: nil))
      return attachment
    }

    // Note: We lose context and hiddenContext on retry since they weren't stored.
    sendMessage(text, context: nil, hiddenContext: nil, codeSelections: codeSelections, attachments: attachments)
  }

  /// Sends a new message to Claude
  /// - Parameters:
  ///   - text: The message text to send
  ///   - context: Optional context to include with the message
  ///   - hiddenContext: Optional hidden context to send to API but not display
  ///   - codeSelections: Optional code selections to display in UI
  ///   - attachments: Optional file attachments (images, PDFs, etc.)
  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil, codeSelections: [TextSelection]? = nil, attachments: [FileAttachment]? = nil) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    ensureProviderMatchesPreferencesForNewSession()

    // Reset cancellation flag for new message
    isCancelled = false

    // Store first message if this is a new session
    if sessionManager.currentSessionId == nil {
      firstMessageInSession = text
    }
    
    // Build message content for display (just the user's text)
    let displayContent = text
    let apiContent = makeOutgoingAPIContent(
      text: text,
      context: context,
      hiddenContext: hiddenContext,
      attachments: attachments
    )

    #if DEBUG
    if activeProvider == .codex,
       ProcessInfo.processInfo.environment["EASEL_DEBUG_CODEX_PROMPT"] == "1" {
      debugPrintCodexPrompt(apiContent)
    }
    #endif

    // Add user message with code selections and attachments for UI display
    let userMessage = MessageFactory.userMessage(content: displayContent, codeSelections: codeSelections, attachments: attachments)
    messageStore.addMessage(userMessage)

    // Invoke the callback for user message logging
    onUserMessageSent?(displayContent, codeSelections, attachments)

    // Clear any previous errors
    errorInfo = nil
    
    // Store the message ID for potential assistant response
    let assistantId = UUID()
    currentMessageId = assistantId
    
    beginLoadingState()
    
    // Track session start
    if !hasSessionStarted {
      hasSessionStarted = true
      // Path will be saved when the session is created in StreamProcessor
    }
    
    // Start conversation
    let task = Task {
      do {
        try await sendRuntimeMessage(prompt: apiContent, messageId: assistantId)
      } catch {
        // A turn cancelled by a workspace/session switch must not post an error
        // into whatever conversation is now showing.
        if Task.isCancelled { return }
        await MainActor.run {
          self.handleError(error, operation: .apiCall)
        }
      }
    }
    runtimeTask = task
  }

  func makeAPIContent(
    text: String,
    context: String? = nil,
    hiddenContext: String? = nil,
    includeRuntimeHiddenContext: Bool = true,
    attachments: [FileAttachment]? = nil
  ) -> String {
    var apiContentParts: [String] = [text]

    // Add image paths to the message text for Claude Code
    if let attachments = attachments, !attachments.isEmpty,
       let imagePaths = AttachmentProcessor.formatImagePathsForMessage(attachments) {
      apiContentParts.insert(imagePaths, at: 1)
    }

    // Add context if present
    if let context = context, !context.isEmpty {
      apiContentParts.append("--- Context ---\n\(context)")
    }

    // Add hidden context if present
    if let combinedHiddenContext = combinedHiddenContext(
      hiddenContext,
      includeRuntimeHiddenContext: includeRuntimeHiddenContext
    ), !combinedHiddenContext.isEmpty {
      apiContentParts.append(combinedHiddenContext)
    }

    // Add attachments metadata in XML format
    if let attachments = attachments, !attachments.isEmpty {
      let attachmentContent = AttachmentProcessor.formatAttachmentsForXML(attachments)
      if !attachmentContent.isEmpty {
        apiContentParts.append(attachmentContent)
      }
    }

    return apiContentParts.joined(separator: "\n\n")
  }

  func makeOutgoingAPIContent(
    text: String,
    context: String? = nil,
    hiddenContext: String? = nil,
    attachments: [FileAttachment]? = nil
  ) -> String {
    let includeRuntimeHiddenContext = shouldIncludeRuntimeHiddenContextForNewMessage()
    let messageHiddenContext = joinedHiddenContexts([
      hiddenContext,
      includeRuntimeHiddenContext ? nil : outgoingHiddenContextProvider?()
    ])

    return makeAPIContent(
      text: text,
      context: context,
      hiddenContext: messageHiddenContext,
      includeRuntimeHiddenContext: includeRuntimeHiddenContext,
      attachments: attachments
    )
  }

  private func combinedHiddenContext(
    _ hiddenContext: String?,
    includeRuntimeHiddenContext: Bool = true
  ) -> String? {
    joinedHiddenContexts([
      hiddenContext,
      includeRuntimeHiddenContext ? runtimeHiddenContextProvider?() : nil
    ])
  }

  private func joinedHiddenContexts(_ contexts: [String?]) -> String? {
    let joined = contexts
      .compactMap { value -> String? in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
      }
      .joined(separator: "\n\n")

    return joined.isEmpty ? nil : joined
  }

  private func shouldIncludeRuntimeHiddenContextForNewMessage() -> Bool {
    guard activeProvider == .codex else {
      return true
    }

    return sessionManager.currentSessionId == nil
  }
  
  /// Clears the conversation history and starts a new session
  public func clearConversation() {
    clearConversation(resetProviderToDefault: true)
  }

  private func clearConversation(resetProviderToDefault: Bool) {
    // Stop any in-flight turn first so it can't keep streaming into the chat
    // after we've cleared it (e.g. when switching to another workspace).
    stopActiveGeneration()
    messageStore.clear()
    sessionManager.clearSession()
    currentMessageId = nil
    errorInfo = nil
    errorQueue.removeAll()
    firstMessageInSession = nil
    hasSessionStarted = false
    currentSessionUsageSummary = .zero
    endLoadingState()
    codexRuntime?.resetSession()
    claudeRuntime?.resetSession()
    runtimeTask = nil
    if resetProviderToDefault {
      setActiveProvider(globalPreferences.chatProvider)
    }
  }

  public func clearVisibleConversationPreservingActiveSession() {
    guard let sessionId = activeSessionId else {
      clearConversation()
      return
    }

    let provider = activeProvider
    let workingDirectory = projectPath
    clearConversation(resetProviderToDefault: false)
    setActiveProvider(provider)
    sessionManager.selectSession(id: sessionId)
    handleSessionChange(sessionId)
    runtime(for: activeProvider).markSessionRestored()

    if !workingDirectory.isEmpty {
      setWorkingDirectory(workingDirectory)
    }
  }
  
  /// Starts a new session without affecting the current session
  public func startNewSession() {
    // Save current session messages before starting new
    Task {
      await saveCurrentSessionMessages()

      // After saving, clear the UI to prepare for new session
      await MainActor.run {
        // Clear only the local state to prepare for a new session
        self.messageStore.clear()
        self.currentMessageId = nil
        self.errorInfo = nil
        self.firstMessageInSession = nil
        self.hasSessionStarted = false
        self.currentSessionUsageSummary = .zero
        
        // Clear the current path to force user to select a new one
        self.settingsStorage.clearProjectPath()
        self.claudeClient.configuration.workingDirectory = nil
        self.codexRuntime?.workingDirectory = nil
        self.claudeRuntime?.workingDirectory = nil
        self.projectPath = ""
        
        // Clear the session manager's current session
        self.sessionManager.clearSession()
        self.codexRuntime?.resetSession()
        self.claudeRuntime?.resetSession()
        self.runtimeTask = nil
        self.setActiveProvider(self.globalPreferences.chatProvider)
        
        // A new session will be created when the user sends their first message
        // Claude will provide the session ID
      }
    }
  }
  
  /// Saves the current session's messages to storage
  private func saveCurrentSessionMessages() async {
    // Only save if we're managing sessions
    guard shouldManageSessions, let sessionId = currentSessionId else {
      return
    }

    let messages = messageStore.getAllMessages()
    do {
      try await sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
      if isDebugEnabled {
        let log = "Saved \(messages.count) messages for current session \(sessionId)"
        logger.debug("\(log)")
      }
    } catch {
      debugLogger.chat("saveCurrentSessionMessages - ERROR: Failed to save messages: \(error)")
      logger.error("Failed to save messages for session \(sessionId): \(error)")
    }
  }

  private func persistCurrentMessagesInBackground() {
    guard shouldManageSessions, let sessionId = currentSessionId else {
      return
    }

    let messages = messageStore.getAllMessages()
    guard !messages.isEmpty else { return }

    Task { [sessionStorage] in
      try? await sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
    }
  }
  
  /// Invalidates any in-flight turn before the conversation is cleared or
  /// a different session is loaded.
  private func stopActiveGeneration() {
    codexRuntime?.cancel()
    claudeRuntime?.cancel()
    runtimeTask?.cancel()
    runtimeTask = nil
  }

  /// Cancels any ongoing requests
  public func cancelRequest() {
    // Set cancellation flag
    isCancelled = true

    runtime(for: activeProvider).cancel()
    runtimeTask?.cancel()
    runtimeTask = nil

    // Cancel any pending tool approval requests
    customPermissionService.cancelAllRequests()

    // Clean up UI state
    endLoadingState()

    // Mark the last message as cancelled
    let messages = messageStore.getAllMessages()
    if let lastMessage = messages.last {
      messageStore.markMessageAsCancelled(id: lastMessage.id)
    }
  }

  /// Handles approval timeout by pausing the conversation
  /// Called by permission service when approval toast has been visible too long
  private func handleApprovalTimeout(toolUseId: String) async {
    logger.info("Pausing conversation due to approval timeout for tool: \(toolUseId)")

    // Cancel the current request
    // This will:
    // 1. Terminate the Claude Code subprocess
    // 2. Clean up the stream
    // 3. Leave the conversation in a clean state (pending tool call is discarded by Claude)
    cancelRequest()

    // Note: The toast remains visible (not hidden)
    // When user approves/denies later, we'll resume the session
  }

  /// Resumes conversation after approval timeout with user's decision
  /// - Parameters:
  ///   - approved: Whether the user approved or denied the tool
  ///   - toolName: Name of the tool that was approved/denied
  public func resumeAfterApprovalTimeout(approved: Bool, toolName: String) async {
    guard let sessionId = currentSessionId else {
      logger.warning("Cannot resume after approval timeout: no active session")
      return
    }

    logger.info("Resuming session \(sessionId) after approval timeout. Tool: \(toolName), Approved: \(approved)")

    // Send a generic message to Claude asking it to continue
    // We don't mention the specific tool - Claude will re-request it if needed
    let prompt = "Please continue with the previous task."

    // Set up loading state
    await MainActor.run {
      self.beginLoadingState()
    }

    let assistantId = UUID()
    await MainActor.run {
      self.currentMessageId = assistantId
    }

    // Resume the conversation
    do {
      try await runtime(for: .claude).send(
        prompt: prompt,
        messageId: assistantId,
        firstMessageInSession: firstMessageInSession
      )
      endLoadingState()
      await saveCurrentSessionMessages()
    } catch {
      await handleSessionResumptionError(error, sessionId: sessionId)
    }
  }

  /// Updates token usage from streaming response
  public func updateTokenUsage(inputTokens: Int, outputTokens: Int) {
    if isDebugEnabled {
      let log = "Updating token usage - input: \(inputTokens), output: \(outputTokens)"
      logger.info("\(log)")
    }
    currentInputTokens = inputTokens
    currentOutputTokens = outputTokens
  }
  
  /// Updates cost from streaming response
  public func updateCost(_ costUSD: Double) {
    if isDebugEnabled {
      let log = "Updating cost: $\(String(format: "%.6f", costUSD))"
      logger.info("\(log)")
    }
    currentCostUSD = costUSD
  }

  private func recordCompletedTurnUsage(_ record: SessionUsageRecord) {
    updateTokenUsage(inputTokens: record.inputTokens, outputTokens: record.outputTokens)

    guard let sessionId = currentSessionId else {
      return
    }

    currentSessionUsageSummary = currentSessionUsageSummary.adding(record)

    guard shouldManageSessions else {
      onSessionUsageChange?(sessionId)
      return
    }

    Task { [sessionStorage, weak self] in
      do {
        try await sessionStorage.recordUsage(id: sessionId, usage: record)
      } catch {
        await MainActor.run {
          self?.debugLogger.chat("recordCompletedTurnUsage - ERROR: Failed to persist usage: \(error)")
          self?.logger.error("Failed to persist usage for session \(sessionId): \(error)")
        }
      }

      await MainActor.run {
        self?.onSessionUsageChange?(sessionId)
      }
    }
  }
  
  /// Loads all available sessions
  public func loadSessions() async {
    // Only fetch sessions if we're managing them
    guard shouldManageSessions else { return }
    await sessionManager.fetchSessions()
  }
  
  /// Selects an existing session (without resuming)
  public func selectSession(id: String) {
    guard let session = sessions.first(where: { $0.id == id }) else { return }
    let sessionId = session.id

    // Notify settings storage of session change
    // Clear current messages
    messageStore.clear()
    currentSessionUsageSummary = session.usageSummary

    // Set the session ID
    setActiveProvider(session.provider)
    sessionManager.selectSession(id: sessionId)
    handleSessionChange(sessionId)
    runtime(for: activeProvider).markSessionRestored()

    // Load and set the session's stored path
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: sessionId) {
      // Validate the path still exists (important for worktrees that might be deleted)
      if FileManager.default.fileExists(atPath: sessionPath) {
        // For worktree validation, we'll do a simplified check without async
        // Just validate that the .git file/directory exists
        let gitPath = (sessionPath as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath) {
          // Update ClaudeClient configuration
          claudeClient.configuration.workingDirectory = sessionPath
          codexRuntime?.workingDirectory = sessionPath
          claudeRuntime?.workingDirectory = sessionPath
          // Update the observable project path
          projectPath = sessionPath
          if isDebugEnabled {
            let log = "Loaded path '\(sessionPath)' for selected session '\(sessionId)'"
            logger.debug("\(log)")
          }
        } else {
          // Git directory no longer exists
          handleInvalidPath(sessionPath, sessionId: sessionId)
        }
      } else {
        // Path no longer exists
        handleInvalidPath(sessionPath, sessionId: sessionId)
      }
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      codexRuntime?.workingDirectory = nil
      claudeRuntime?.workingDirectory = nil
      projectPath = ""
      if isDebugEnabled {
        let log = "No stored path for selected session '\(sessionId)'"
        logger.debug("\(log)")
      }
    }
    
    // We would load previous messages here if we had that capability
    // For now, we're just switching to the session
    
    // Clear any errors
    errorInfo = nil
  }
  
  /// Resumes an existing session with optional initial prompt
  public func resumeSession(id: String, initialPrompt: String? = nil) async {
    // Ensure sessions are loaded and validate
    guard await validateSessionExists(id: id) else { return }
    
    if isDebugEnabled {
      let log = "Resuming session: \(id)"
      logger.debug("\(log)")
    }
    
    // Prepare session for resumption
    prepareSessionForResumption(id: id, provider: sessions.first { $0.id == id }?.provider)

    // Load messages for this session
    do {
      if let session = try await sessionStorage.getSession(id: id) {
        setActiveProvider(session.provider)
        runtime(for: activeProvider).markSessionRestored()
        messageStore.loadMessages(session.messages)
        currentSessionUsageSummary = session.usageSummary
        if isDebugEnabled {
          let log = "Loaded \(session.messages.count) messages for session \(id)"
          logger.debug("\(log)")
        }
      }
    } catch {
      logger.error("Failed to load messages for session \(id): \(error)")
    }
    
    // Setup for conversation resumption
    let assistantId = UUID()
    setupConversationResumption(assistantId: assistantId, initialPrompt: initialPrompt)
    
    // Resume the conversation
    await performSessionResumption(id: id, initialPrompt: initialPrompt, assistantId: assistantId)
  }
  
  /// Injects a session with messages from an external source (e.g., database)
  /// This is designed for apps that manage their own message storage
  /// - Parameters:
  ///   - sessionId: The session ID to use for Claude CLI
  ///   - messages: The chat history to display in the UI
  ///   - workingDirectory: Optional working directory for this session
  /// - Note: The messages are displayed in UI, but Claude CLI won't have the context
  ///         unless it already knows about this sessionId
  /// Updates the working directory for new sessions without affecting session state.
  public func setWorkingDirectory(_ directory: String) {
    let normalizedDirectory = directory.isEmpty ? nil : directory
    claudeClient.configuration.workingDirectory = normalizedDirectory
    codexRuntime?.workingDirectory = normalizedDirectory
    claudeRuntime?.workingDirectory = normalizedDirectory
    projectPath = normalizedDirectory ?? ""
    settingsStorage.setProjectPath(projectPath)
  }

  public func injectSession(
    sessionId: String,
    messages: [ChatMessage],
    workingDirectory: String? = nil,
    provider: ChatProvider? = nil,
    usageSummary: SessionUsageSummary = .zero
  ) {
    // Stop any in-flight turn from the previous session/workspace so it can't
    // stream into or persist over the session we're about to load.
    stopActiveGeneration()

    // Set up the session
    setActiveProvider(provider ?? globalPreferences.chatProvider)
    sessionManager.selectSession(id: sessionId)
    handleSessionChange(sessionId)
    currentSessionUsageSummary = usageSummary

    // Set working directory if provided
    if let dir = workingDirectory {
      claudeClient.configuration.workingDirectory = dir
      codexRuntime?.workingDirectory = dir
      claudeRuntime?.workingDirectory = dir
      projectPath = dir
      settingsStorage.setProjectPath(dir)
    }

    // Load the messages into the UI
    messageStore.loadMessages(messages)

    // Mark as active session
    hasSessionStarted = true
    runtime(for: activeProvider).markSessionRestored()
    errorInfo = nil
    
    if isDebugEnabled {
      let log = "Injected session '\(sessionId)' with \(messages.count) messages"
      logger.info("\(log)")
    }
  }
  
  /// Deletes a session
  public func deleteSession(id: String) async {
    // If deleting the current session, clear the chat interface and working directory
    if currentSessionId == id {
      clearConversation()

      // Apply default working directory if available
      let defaultDirectory = globalPreferences.defaultWorkingDirectory
      if !defaultDirectory.isEmpty {
        claudeClient.configuration.workingDirectory = defaultDirectory
        codexRuntime?.workingDirectory = defaultDirectory
        claudeRuntime?.workingDirectory = defaultDirectory
        projectPath = defaultDirectory
        settingsStorage.setProjectPath(defaultDirectory)
      } else {
        // Only clear if no default is set
        settingsStorage.clearProjectPath()
        claudeClient.configuration.workingDirectory = nil
        codexRuntime?.workingDirectory = nil
        claudeRuntime?.workingDirectory = nil
        projectPath = ""
      }
    }

    // Delete from storage
    await sessionManager.deleteSession(id: id)
  }
  
  /// Switches to a different session in the same window
  public func switchToSession(_ sessionId: String) async {
    // Only switch if we're managing sessions
    guard shouldManageSessions else { return }
    
    // If switching to the same session, do nothing
    guard sessionId != currentSessionId else { return }
    
    // Prevent concurrent session switches
    guard !isSwitchingSession else {
      logger.warning("Already switching sessions, ignoring switch to \(sessionId)")
      return
    }
    
    isSwitchingSession = true
    defer { isSwitchingSession = false }
    
    if isDebugEnabled {
      let log = "Switching to session: \(sessionId)"
      logger.debug("\(log)")
    }
    
    // Cancel any ongoing requests first
    if isLoading {
      cancelRequest()
      // Small delay to ensure cancellation completes
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
    }
    
    // Save current session messages before switching
    if let currentId = currentSessionId {
      let currentMessages = messageStore.getAllMessages()
      do {
        try await sessionStorage.updateSessionMessages(id: currentId, messages: currentMessages)
        if isDebugEnabled {
          let log = "Saved \(currentMessages.count) messages for session \(currentId)"
          logger.debug("\(log)")
        }
      } catch {
        logger.error("Failed to save messages for session \(currentId): \(error)")
      }
    }
    
    // Clear current conversation
    clearConversation()
    
    // Resume the selected session
    await resumeSession(id: sessionId)
  }
  
  // MARK: - Session Resumption Helpers
  
  private func validateSessionExists(id: String) async -> Bool {
    // Skip validation if not managing sessions
    guard shouldManageSessions else { return false }
    
    // First ensure sessions are loaded
    if sessions.isEmpty {
      await loadSessions()
    }
    
    // Verify the session exists
    guard sessions.contains(where: { $0.id == id }) else {
      logger.error("Session \(id) not found in stored sessions")
      return false
    }
    
    return true
  }
  
  private func prepareSessionForResumption(id: String, provider: ChatProvider?) {
    // Clear current messages
    messageStore.clear()
    
    // Set the session ID BEFORE any async operations
    setActiveProvider(provider ?? .codex)
    sessionManager.selectSession(id: id)
    runtime(for: activeProvider).markSessionRestored()
    
    // Notify settings storage of session change
    handleSessionChange(id)
    
    // Load and set the session's stored path
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: id) {
      // Update ClaudeClient configuration
      claudeClient.configuration.workingDirectory = sessionPath
      codexRuntime?.workingDirectory = sessionPath
      claudeRuntime?.workingDirectory = sessionPath
      // Update the observable project path
      projectPath = sessionPath
      if isDebugEnabled {
        let log = "Loaded path '\(sessionPath)' for resumed session '\(id)'"
        logger.debug("\(log)")
      }
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      codexRuntime?.workingDirectory = nil
      claudeRuntime?.workingDirectory = nil
      projectPath = ""
      if isDebugEnabled {
        let log = "No stored path for resumed session '\(id)'"
        logger.debug("\(log)")
      }
    }
    
    // Clear any errors
    errorInfo = nil
    
    // Mark session as already started since we're resuming
    hasSessionStarted = true
    
    // Update last accessed time
    sessionManager.updateLastAccessed(id: id)
  }
  
  private func setupConversationResumption(assistantId: UUID, initialPrompt: String?) {
    // Only set loading state if we have a prompt to send
    if let prompt = initialPrompt, !prompt.isEmpty {
      beginLoadingState()
      currentMessageId = assistantId
      
      // Add the user message
      let userMessage = MessageFactory.userMessage(content: prompt)
      messageStore.addMessage(userMessage)
    } else {
      // Just switching sessions, no loading state
      currentMessageId = nil
    }
  }
  
  private func performSessionResumption(id: String, initialPrompt: String?, assistantId: UUID) async {
    // Ensure we're resuming the correct session
    if id != sessionManager.currentSessionId {
      if isDebugEnabled {
        let log = "Switching to resume session '\(id)'"
        logger.info("\(log)")
      }
      // Update to match the requested session
      sessionManager.selectSession(id: id)
    }
    
    // Only make API call if there's an actual prompt to send
    guard let prompt = initialPrompt, !prompt.isEmpty else {
      // Just switch to the session without making an API call
      if isDebugEnabled {
        let log = "Switched to session \(id) without sending a message"
        logger.debug("\(log)")
      }
      
      // Mark as not loading since we're not making an API call
      await MainActor.run {
        self.endLoadingState()
      }
      return
    }
    
    if isDebugEnabled {
      let log = "📤 Resuming session '\(id)' after app relaunch with new message"
      logger.info("\(log)")
    }
    
    do {
      try await sendRuntimeMessage(prompt: prompt, messageId: assistantId)
    } catch {
      await handleSessionResumptionError(error, sessionId: id)
    }
  }
  
  private func handleSessionResumptionError(_ error: Error, sessionId: String) async {
    logger.error("Failed to resume session \(sessionId): \(error.localizedDescription)")
    
    await MainActor.run {
      self.endLoadingState()
      
      // Check if it's a "conversation not found" error
      let errorMessage = error.localizedDescription.lowercased()
      if errorMessage.contains("no conversation") || errorMessage.contains("not found") {
        // Session exists in our storage but not in Claude
        // This is expected after app restart - Claude sessions don't persist
        if isDebugEnabled {
          let log = "Session \(sessionId) exists locally but not in Claude. Continuing with local history."
          logger.info("\(log)")
        }
        self.errorInfo = nil
        
        // Keep the session active with its message history
        // User can continue the conversation, and Claude will create a new backend session
      } else {
        // Some other error
        self.handleError(error)
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func sendRuntimeMessage(prompt: String, messageId: UUID) async throws {
    try validateWorkingDirectory()

    let runtime = runtime(for: activeProvider)
    configure(runtime)
    try await runtime.send(
      prompt: prompt,
      messageId: messageId,
      firstMessageInSession: firstMessageInSession
    )

    await MainActor.run {
      self.endLoadingState()
      self.firstMessageInSession = nil
    }

    await saveCurrentSessionMessages()
  }

  private func runtime(for provider: ChatProvider) -> any ChatRuntime {
    switch provider.supportedProvider {
    case .codex:
      return getCodexRuntime()
    case .claude:
      return getClaudeRuntime()
    }
  }

  private func configure(_ runtime: any ChatRuntime) {
    runtime.workingDirectory = claudeClient.configuration.workingDirectory

    if let codexRuntime = runtime as? CodexChatRuntime {
      codexRuntime.developerInstructions = combinedCodexDeveloperInstructions()
      codexRuntime.modelIdentifier = globalPreferences.codexModel
      codexRuntime.commandOverride = globalPreferences.codexCommand
      codexRuntime.extraArguments = CodexChatRuntime.parseArgumentString(globalPreferences.codexExtraArgs)
      codexRuntime.environmentOverrides = globalPreferences.codexEnvironmentVariables
    }
  }

  private func getCodexRuntime() -> CodexChatRuntime {
    if let codexRuntime {
      return codexRuntime
    }

    let runtime = CodexChatRuntime(
      messageDisplay: messageStore,
      sessionManager: sessionManager,
      workingDirectory: claudeClient.configuration.workingDirectory,
      developerInstructions: combinedCodexDeveloperInstructions(),
      modelIdentifier: globalPreferences.codexModel,
      commandOverride: globalPreferences.codexCommand,
      extraArguments: CodexChatRuntime.parseArgumentString(globalPreferences.codexExtraArgs),
      environmentOverrides: globalPreferences.codexEnvironmentVariables,
      onSessionChange: { [weak self] sessionId in
        self?.handleRuntimeSessionChange(sessionId)
      },
      onUsageRecorded: { [weak self] record in
        self?.recordCompletedTurnUsage(record)
      }
    )
    codexRuntime = runtime
    return runtime
  }

  private func getClaudeRuntime() -> ClaudeChatRuntime {
    if let claudeRuntime {
      return claudeRuntime
    }

    let runtime = ClaudeChatRuntime(
      claudeClient: claudeClient,
      sessionManager: sessionManager,
      streamProcessor: streamProcessor,
      globalPreferences: globalPreferences,
      systemPromptPrefix: systemPromptPrefix,
      onError: { [weak self] error, operation in
        self?.handleError(error, operation: operation)
      },
      onTokenUsageUpdate: { [weak self] inputTokens, outputTokens in
        self?.updateTokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)
      },
      onCostUpdate: { [weak self] costUSD in
        self?.updateCost(costUSD)
      },
      onUsageRecord: { [weak self] record in
        self?.recordCompletedTurnUsage(record)
      },
      onResultReceived: { [weak self] in
        self?.endLoadingState()
      }
    )
    claudeRuntime = runtime
    return runtime
  }

  private func combinedCodexDeveloperInstructions() -> String? {
    let parts = [
      codexDeveloperInstructionsPrefix ?? systemPromptPrefix,
      globalPreferences.systemPrompt,
      globalPreferences.appendSystemPrompt,
    ]
      .compactMap { value -> String? in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
      }

    return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
  }

  #if DEBUG
  private func debugPrintCodexPrompt(_ prompt: String) {
    print("""

    ===== EASEL CODEX PROMPT BEGIN =====
    \(prompt)
    ===== EASEL CODEX PROMPT END =====

    """)
  }
  #endif
  
  
  @MainActor
  func handleError(_ error: Error, operation: ErrorOperation = .general) {
    logger.error("Error: \(error.localizedDescription)")

    // Capture error for debug reporting
    lastError = error

    // Create detailed error info based on operation type
    var errorInfo: ErrorInfo
    switch operation {
    case .sessionManagement:
      errorInfo = ErrorInfo.sessionError(error)
    case .streaming:
      errorInfo = ErrorInfo.streamingError(error)
    case .apiCall:
      errorInfo = ErrorInfo.apiError(error)
    case .fileOperation:
      errorInfo = ErrorInfo.fileError(error)
    default:
      errorInfo = ErrorInfo(
        error: error,
        severity: .error,
        context: "Operation failed",
        recoverySuggestion: "Please try again or check your settings.",
        operation: operation
      )
    }

    // For notInstalled errors, enhance with the actual command being used
    if let claudeError = error as? ClaudeCodeError,
       case .notInstalled = claudeError {
      let actualCommand = globalPreferences.claudeCommand
      if isDebugEnabled {
        logger.debug("[DEBUG] Command configured: '\(actualCommand)'")
      }

      // Check if it looks like a typo
      if actualCommand != "claude" && actualCommand.contains("cl") {
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Command '\(actualCommand)' Not Found",
          recoverySuggestion: "The command '\(actualCommand)' was not found. Verify the command is installed and available in PATH.",
          operation: .configuration
        )
      } else if actualCommand == "claude" {
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Assistant Command Not Installed",
          recoverySuggestion: "The configured assistant command is not installed or is not available in PATH.",
          operation: .configuration
        )
      } else {
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Command '\(actualCommand)' Not Found",
          recoverySuggestion: "The command '\(actualCommand)' was not found in PATH.",
          operation: .configuration
        )
      }
    }

    self.errorInfo = errorInfo
    self.errorQueue.append(errorInfo)
    endLoadingState()

    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId {
      messageStore.removeMessage(id: currentMessageId)
    }
  }

  private struct LoadingSessionIdentity: Equatable {
    let sessionId: String?
    let workingDirectory: String?

    func matches(_ currentIdentity: LoadingSessionIdentity) -> Bool {
      if let sessionId {
        return currentIdentity.sessionId == sessionId
      }

      return currentIdentity.sessionId == nil
        && currentIdentity.workingDirectory == workingDirectory
    }

    func replacingSessionId(_ sessionId: String) -> LoadingSessionIdentity {
      LoadingSessionIdentity(
        sessionId: sessionId,
        workingDirectory: workingDirectory
      )
    }
  }

  // MARK: - Working Directory Validation

  /// Validates the working directory before launching subprocess
  /// Throws an error if the directory is invalid, doesn't exist, or has git worktree issues
  private func validateWorkingDirectory() throws {
    guard let workingDir = claudeClient.configuration.workingDirectory, !workingDir.isEmpty else {
      // No working directory set - this should not happen as we always set a fallback
      debugLogger.log(.chat, "[ChatViewModel] WARNING: No working directory configured")
      throw ClaudeCodeError.executionFailed("No working directory set. Please select a directory in Settings or restart the application.")
    }

    // Check if directory exists
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: workingDir, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      // Clear the invalid directory immediately
      claudeClient.configuration.workingDirectory = nil
      codexRuntime?.workingDirectory = nil
      claudeRuntime?.workingDirectory = nil
      projectPath = ""
      settingsStorage.clearProjectPath()

      // Provide clear instructions to the user
      let errorMessage = "Working directory does not exist: \(workingDir)\n\nThe directory has been cleared. To continue:\n1. Start a new session (trash icon)\n2. Select a valid working directory in Settings"
      throw ClaudeCodeError.executionFailed(errorMessage)
    }

    // Check if it's a git repository (has .git file or directory)
    let gitPath = (workingDir as NSString).appendingPathComponent(".git")
    guard FileManager.default.fileExists(atPath: gitPath) else {
      // Not a git repo - this is OK, just skip worktree validation
      return
    }

    // Validate git worktree if applicable
    try validateGitWorktree(at: workingDir, gitPath: gitPath)
  }

  /// Validates a git worktree to ensure it's not corrupted or pointing to a deleted location
  private func validateGitWorktree(at workingDir: String, gitPath: String) throws {
    var isDirectory: ObjCBool = false
    let gitIsDirectory = FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) && isDirectory.boolValue

    // If .git is a directory, it's a normal git repo (not a worktree)
    guard !gitIsDirectory else { return }

    // .git is a file - this is a worktree. Read the file to check the gitdir reference
    guard let gitFileContents = try? String(contentsOfFile: gitPath, encoding: .utf8) else {
      throw ClaudeCodeError.executionFailed("Cannot read .git file in worktree: \(gitPath)")
    }

    // Extract gitdir path from the .git file (format: "gitdir: /path/to/repo/.git/worktrees/name")
    let gitdirPrefix = "gitdir: "
    guard gitFileContents.hasPrefix(gitdirPrefix) else {
      throw ClaudeCodeError.executionFailed("Invalid .git file format in worktree: \(gitPath)")
    }

    let gitdirPath = gitFileContents
      .dropFirst(gitdirPrefix.count)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    // Check if the referenced gitdir exists
    guard FileManager.default.fileExists(atPath: gitdirPath) else {
      throw ClaudeCodeError.executionFailed("Git worktree is corrupted or points to deleted location.\n\nWorktree path: \(workingDir)\nMissing gitdir: \(gitdirPath)\n\nThis worktree has been pruned or the main repository was moved/deleted.\nPlease select a different working directory or repair the worktree.")
    }
  }

  // MARK: - Worktree Support Helpers

  /// Handles the case when a path is no longer valid
  private func handleInvalidPath(_ path: String, sessionId: String) {
    claudeClient.configuration.workingDirectory = nil
    codexRuntime?.workingDirectory = nil
    claudeRuntime?.workingDirectory = nil
    projectPath = ""

    let errorMessage = "The directory '\(path)' no longer exists or is invalid. Please select a new working directory."
    logger.warning("\(errorMessage)")

    // Create a generic execution failed error since we don't have invalidPath
    let error = ClaudeCodeError.executionFailed("Invalid path: \(path)")

    errorInfo = ErrorInfo(
      error: error,
      severity: .warning,
      context: "Directory Not Found",
      recoverySuggestion: errorMessage,
      operation: .sessionManagement
    )
  }

  // MARK: - Plan Approval

  /// Updates the plan approval status for a specific message
  public func updatePlanApprovalStatus(messageId: UUID, status: PlanApprovalStatus) {
    messageStore.updatePlanApprovalStatus(id: messageId, status: status)
  }
}
