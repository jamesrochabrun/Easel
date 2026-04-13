//
//  ChatService.swift
//  EaselChat
//

import ClaudeCodeCore
import ClaudeCodeSDK
import EaselKit
import Foundation

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
  public private(set) var sessionStorage: SessionStorageProtocol

  /// Called when a session changes (created or switched), so the sidebar can refresh
  public var onSessionChanged: (() -> Void)?

  private var hasSentInitialPrompt = false
  private let previewURLObserver = PreviewURLObserver()

  // MARK: - Init

  public init() {
    sessionStorage = SimplifiedClaudeCodeSQLiteStorage()
  }

  // MARK: - Initialization

  public func initialize() async {
    do {
      let globalPrefs = GlobalPreferencesStorage()
      let container = DependencyContainer(
        globalPreferences: globalPrefs,
        customSessionStorage: sessionStorage
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
      }

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
    Task { await initialize() }
  }

  // MARK: - ChatServiceProtocol

  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    chatViewModel?.sendMessage(text, context: context, hiddenContext: hiddenContext)
  }

  // MARK: - InspectorBridgeProtocol

  public func sendInspectorPrompt(_ prompt: String) {
    chatViewModel?.sendMessage(prompt)
  }

  public func sendContextPrompt(_ prompt: String) {
    chatViewModel?.sendMessage(prompt, hiddenContext: prompt)
  }

  public func sendCropPrompt(_ prompt: String) {
    chatViewModel?.sendMessage(prompt)
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
    previewURL = nil
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
    }

    currentSessionId = nil
    previewURL = nil
    startPreviewObservation()
  }

  public func deleteSession(_ session: StoredSession) async {
    try? await sessionStorage.deleteSession(id: session.id)
    if currentSessionId == session.id {
      currentSessionId = nil
      chatViewModel?.clearConversation()
    }
  }

  // MARK: - Initial Prompt

  public func sendInitialPromptIfNeeded(_ prompt: String) {
    guard !hasSentInitialPrompt, !prompt.isEmpty else { return }
    hasSentInitialPrompt = true
    chatViewModel?.sendMessage(prompt)
  }

  // MARK: - Private

  private func startPreviewObservation() {
    previewURLObserver.startObserving(
      messages: { [weak self] in
        self?.chatViewModel?.messages ?? []
      },
      onURLDetected: { [weak self] url in
        self?.previewURL = url
      }
    )
  }
}
