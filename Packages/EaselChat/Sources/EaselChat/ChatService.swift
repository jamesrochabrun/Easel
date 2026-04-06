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

  private var hasSentInitialPrompt = false

  // MARK: - Init

  public init() {}

  // MARK: - Initialization

  public func initialize() async {
    do {
      let globalPrefs = GlobalPreferencesStorage()
      let container = DependencyContainer.forDirectChatScreen(globalPreferences: globalPrefs)

      var config = ChatConfiguration.makeDefault()
      config.command = globalPrefs.claudeCommand

      let client = try ClaudeCodeClient(configuration: config)
      let vm = container.createChatViewModelWithoutSessions(
        claudeClient: client,
        workingDirectory: config.workingDirectory
      )

      self.chatViewModel = vm
      self.deps = container
      self.globalPreferences = globalPrefs
      self.isInitialized = true
    } catch {
      self.initError = error
    }
  }

  public func retry() {
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

  // MARK: - Initial Prompt

  public func sendInitialPromptIfNeeded(_ prompt: String) {
    guard !hasSentInitialPrompt, !prompt.isEmpty else { return }
    hasSentInitialPrompt = true
    chatViewModel?.sendMessage(prompt)
  }
}
