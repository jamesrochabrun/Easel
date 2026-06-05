//
//  ChatService.swift
//  EaselChat
//

import ClaudeCodeCore
import ClaudeCodeSDK
import EaselKit
import Foundation
import OSLog

private let chatLog = Logger(subsystem: "com.easel.chat", category: "ChatService")

@Observable @MainActor
public final class ChatService: ChatServiceProtocol, InspectorBridgeProtocol, PreviewURLProviding {

  // MARK: - Public State

  public private(set) var chatViewModel: ChatViewModel?
  public private(set) var deps: DependencyContainer?
  public private(set) var globalPreferences: GlobalPreferencesStorage?
  public private(set) var isInitialized = false
  public private(set) var initError: Error?
  public private(set) var previewURL: URL?
  public private(set) var currentSessionId: String?
  public private(set) var currentWorkingDirectory: String?
  public private(set) var currentProject: EaselDesignProject?
  public private(set) var sessionStorage: SessionStorageProtocol
  public var mcpToolsDiscoveryService: MCPToolsDiscoveryService { mcpToolsDiscovery }

  /// Called when a session changes (created or switched), so the sidebar can refresh
  public var onSessionChanged: (() -> Void)?

  private var isInitializing = false
  private let previewURLObserver = PreviewURLObserver()
  private let projectManager: any EaselProjectManaging
  private let persistentPreferencesManager: PersistentPreferencesManager
  private let mcpToolsDiscovery: MCPToolsDiscoveryService
  private let logger: ClaudeCodeLogger
  private var previewURLSource: PreviewURLSource?
  private var currentProjectLookupTask: Task<Void, Never>?

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol = SimplifiedClaudeCodeSQLiteStorage(),
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    persistentPreferencesManager: PersistentPreferencesManager? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger()
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.logger = logger
    self.persistentPreferencesManager = persistentPreferencesManager ?? PersistentPreferencesManager(logger: logger)
  }

  // MARK: - Initialization

  public func initialize() async {
    guard !isInitialized else { return }
    if isInitializing {
      while isInitializing && !isInitialized {
        try? await Task.sleep(for: .milliseconds(50))
      }
      return
    }

    isInitializing = true
    defer { isInitializing = false }

    do {
      let globalPrefs = GlobalPreferencesStorage(
        persistentManager: persistentPreferencesManager,
        logger: logger
      )
      let container = DependencyContainer(
        globalPreferences: globalPrefs,
        customSessionStorage: sessionStorage,
        mcpToolsDiscovery: mcpToolsDiscovery,
        logger: logger
      )

      var config = ChatConfiguration.makeDefault()
      config.command = globalPrefs.claudeCommand

      let client = try ClaudeCodeClient(configuration: config)

      // Set working directory
      if let dir = config.workingDirectory {
        container.settingsStorage.setProjectPath(dir)
      }

      let vm = ChatViewModel(
        claudeClient: client,
        sessionStorage: sessionStorage,
        settingsStorage: container.settingsStorage,
        globalPreferences: globalPrefs,
        customPermissionService: container.customPermissionService,
        mcpToolsDiscovery: mcpToolsDiscovery,
        logger: logger,
        systemPromptPrefix: EaselAgentInstructions.systemPromptPrefix,
        codexDeveloperInstructionsPrefix: EaselAgentInstructions.codexDeveloperInstructionsPrefix,
        shouldManageSessions: true,
        onSessionChange: { [weak self] newSessionId in
          Task { @MainActor in
            self?.currentSessionId = newSessionId
            self?.onSessionChanged?()
          }
        }
      )

      if let dir = config.workingDirectory {
        vm.projectPath = dir
        setCurrentWorkingDirectory(dir)
      }
      setCurrentWorkingDirectory(vm.projectPath)

      self.chatViewModel = vm
      self.deps = container
      self.globalPreferences = globalPrefs
      self.isInitialized = true

      startPreviewObservation()
    } catch {
      self.initError = error
    }
  }

  public func retry() {
    previewURLObserver.stopObserving()
    initError = nil
    isInitialized = false
    clearPreviewURL()
    Task { await initialize() }
  }

  // MARK: - ChatServiceProtocol

  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    sendMessageToViewModel(text, context: context, hiddenContext: hiddenContext)
  }

  // MARK: - InspectorBridgeProtocol

  public func sendInspectorPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt)
  }

  public func sendContextPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt, hiddenContext: prompt)
  }

  public func sendCropPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt)
  }

  // MARK: - Session Management

  public func switchToSession(_ session: StoredSession) async {
    previewURLObserver.stopObserving()

    // Save current session before switching
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }

    // Load fresh session data from storage, fall back to the passed object
    let sessionToLoad: StoredSession
    if let stored = try? await sessionStorage.getSession(id: session.id) {
      sessionToLoad = stored
    } else {
      sessionToLoad = session
    }

    // injectSession handles updating working directory on the existing client
    chatViewModel?.injectSession(
      sessionId: sessionToLoad.id,
      messages: sessionToLoad.messages,
      workingDirectory: sessionToLoad.workingDirectory
    )

    currentSessionId = session.id
    setCurrentWorkingDirectory(chatViewModel?.projectPath)
    clearPreviewURL()

    // Immediately scan loaded messages for a dev server URL
    if let detectedURL = previewURLObserver.scanExistingMessages(sessionToLoad.messages) {
      applyDetectedPreviewURL(detectedURL)
    }

    startPreviewObservation()
  }

  public func startNewSession(workingDirectory: String?) async {
    previewURLObserver.stopObserving()

    // Save current session before starting new one
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }

    chatViewModel?.clearConversation()

    // Set the working directory for the new chat
    if let dir = workingDirectory, !dir.isEmpty {
      chatViewModel?.setWorkingDirectory(dir)
      setCurrentWorkingDirectory(dir)
    } else {
      setCurrentWorkingDirectory(chatViewModel?.projectPath)
    }

    currentSessionId = nil
    clearPreviewURL()
    startPreviewObservation()
  }

  public func deleteSession(_ session: StoredSession) async {
    try? await sessionStorage.deleteSession(id: session.id)
    if currentSessionId == session.id {
      currentSessionId = nil
      chatViewModel?.clearConversation()
    }
  }

  // MARK: - Preview URL

  public func setPreviewURL(_ url: URL) {
    chatLog.info("Preview URL set: \(url.absoluteString)")
    previewURL = url
    previewURLSource = .appManaged
    // The app now owns the preview. Detected URLs from messages are ignored while
    // app-managed, so stop the message scan loop to avoid pointless per-message rescans.
    previewURLObserver.stopObserving()
  }

  public func setCurrentProject(_ project: EaselDesignProject?) {
    currentProjectLookupTask?.cancel()
    currentProject = project
    currentWorkingDirectory = project?.workingDirectory
  }

  // MARK: - Private

  private func startPreviewObservation() {
    previewURLObserver.startObserving(
      messages: { [weak self] in
        self?.chatViewModel?.messages ?? []
      },
      onURLDetected: { [weak self] url in
        chatLog.info("Live observation detected URL: \(url.absoluteString)")
        self?.applyDetectedPreviewURL(url)
      }
    )
  }

  func applyDetectedPreviewURL(_ url: URL) {
    guard previewURLSource != .appManaged else {
      chatLog.info("Ignoring detected preview URL because app-managed preview is active: \(url.absoluteString)")
      return
    }

    previewURL = url
    previewURLSource = .detected
  }

  private func clearPreviewURL() {
    previewURL = nil
    previewURLSource = nil
  }

  private func sendMessageToViewModel(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    let combinedHiddenContext = EaselAgentInstructions.appendingHiddenContext(
      hiddenContext,
      projectPath: currentWorkingDirectory,
      projectKind: currentProject?.kind,
      projectFidelity: currentPrototypeFidelity,
      previewURL: previewURL
    )
    chatViewModel?.sendMessage(text, context: context, hiddenContext: combinedHiddenContext)
  }

  private var currentPrototypeFidelity: EaselProjectFidelity? {
    guard currentProject?.kind == .prototype else { return nil }
    return currentProject?.fidelity
  }

  private func setCurrentWorkingDirectory(_ path: String?) {
    let normalized = path?.trimmingCharacters(in: .whitespacesAndNewlines)
    currentWorkingDirectory = normalized?.isEmpty == false ? normalized : nil
    refreshCurrentProjectMetadata(for: currentWorkingDirectory)
  }

  private func refreshCurrentProjectMetadata(for workingDirectory: String?) {
    currentProjectLookupTask?.cancel()

    guard let workingDirectory else {
      currentProject = nil
      return
    }

    currentProject = nil
    currentProjectLookupTask = Task { [projectManager] in
      let projects = (try? await projectManager.loadProjects()) ?? []
      let project = projects.first { $0.workingDirectory == workingDirectory }

      guard !Task.isCancelled else { return }

      await MainActor.run { [weak self] in
        guard self?.currentWorkingDirectory == workingDirectory else { return }
        self?.currentProject = project
      }
    }
  }
}

private enum PreviewURLSource {
  case appManaged
  case detected
}
