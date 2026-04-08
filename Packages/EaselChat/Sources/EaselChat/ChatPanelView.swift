//
//  ChatPanelView.swift
//  EaselChat
//

import ClaudeCodeCore
import SwiftUI

public struct ChatPanelView: View {
  let chatService: ChatService
  let initialPrompt: String

  @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

  public init(chatService: ChatService, initialPrompt: String) {
    self.chatService = chatService
    self.initialPrompt = initialPrompt
  }

  public var body: some View {
    Group {
      if let error = chatService.initError {
        errorView(error)
      } else if chatService.isInitialized,
        let vm = chatService.chatViewModel,
        let deps = chatService.deps,
        let globalPreferences = chatService.globalPreferences
      {
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
            showTokenCount: true,
            messageFontSize: 13.0,
            inputCornerRadius: 8.0,
            useMaterialInputBackground: true,
            showCommandTip: false
          )
        )
        .environment(globalPreferences)
        .onAppear {
          chatService.sendInitialPromptIfNeeded(initialPrompt)
        }
      } else {
        ProgressView("Initializing...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      await chatService.initialize()
    }
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
        chatService.retry()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
