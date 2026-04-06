//
//  ChatPanelView.swift
//  Easel
//

import ClaudeCodeCore
import ClaudeCodeSDK
import SwiftUI

struct ChatPanelView: View {
  let initialPrompt: String

  @State private var chatViewModel: ChatViewModel?
  @State private var deps: DependencyContainer?
  @State private var globalPreferences: GlobalPreferencesStorage?
  @State private var isInitialized = false
  @State private var initError: Error?
  @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
  @State private var hasSentInitialPrompt = false

  var body: some View {
    Group {
      if let error = initError {
        errorView(error)
      } else if isInitialized, let vm = chatViewModel, let deps, let globalPreferences {
        ChatScreen(
          viewModel: vm,
          contextManager: deps.contextManager,
          xcodeObservationViewModel: deps.xcodeObservationViewModel,
          permissionsService: deps.permissionsService,
          terminalService: deps.terminalService,
          customPermissionService: deps.customPermissionService,
          columnVisibility: $columnVisibility,
          uiConfiguration: UIConfiguration(
            appName: "Easel",
            showSettingsInNavBar: false,
            showRiskData: false,
            showTokenCount: true
          )
        )
        .environment(globalPreferences)
        .onAppear {
          sendInitialPromptIfNeeded(vm)
        }
      } else {
        ProgressView("Initializing...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      await initialize()
    }
    .background(GlassBackgroundView(material: .sidebar))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  // MARK: - Initialization

  private func initialize() async {
    do {
      let globalPrefs = GlobalPreferencesStorage()
      let container = DependencyContainer.forDirectChatScreen(globalPreferences: globalPrefs)

      var config = Self.makeClaudeCodeConfiguration()
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

  private func sendInitialPromptIfNeeded(_ vm: ChatViewModel) {
    guard !hasSentInitialPrompt, !initialPrompt.isEmpty else { return }
    hasSentInitialPrompt = true
    vm.sendMessage(initialPrompt)
  }

  // MARK: - Configuration

  private static func makeClaudeCodeConfiguration() -> ClaudeCodeConfiguration {
    var config = ClaudeCodeConfiguration.withNvmSupport()
    config.enableDebugLogging = true
    let homeDir = NSHomeDirectory()
    config.workingDirectory = homeDir

    let localClaudePath = "\(homeDir)/.claude/local"
    if FileManager.default.fileExists(atPath: localClaudePath) {
      config.additionalPaths.insert(localClaudePath, at: 0)
    }
    config.additionalPaths.append(contentsOf: [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.bun/bin",
      "\(homeDir)/.deno/bin",
      "\(homeDir)/.cargo/bin",
      "\(homeDir)/.local/bin",
    ])

    return config
  }

  // MARK: - Error View

  private func errorView(_ error: Error) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 36))
        .foregroundStyle(.red)

      Text("Initialization Failed")
        .font(.title3.weight(.semibold))

      Text(error.localizedDescription)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button("Retry") {
        initError = nil
        isInitialized = false
        Task { await initialize() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
