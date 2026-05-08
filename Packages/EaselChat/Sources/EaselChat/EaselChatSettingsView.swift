//
//  EaselChatSettingsView.swift
//  EaselChat
//

import ClaudeCodeCore
import SwiftUI

public struct EaselChatSettingsView: View {
  private let chatService: ChatService?

  public init(chatService: ChatService? = nil) {
    self.chatService = chatService
  }

  public var body: some View {
    ClaudeCodeGlobalSettingsSceneView(
      uiConfiguration: UIConfiguration(
        appName: "Easel",
        showSettingsInNavBar: false,
        showRiskData: false,
        showTokenCount: true,
        messageFontSize: 13.0,
        inputCornerRadius: 8.0,
        useMaterialInputBackground: true,
        showCommandTip: false,
        showWelcomeRow: false
      ),
      xcodeObservationViewModel: chatService?.deps?.xcodeObservationViewModel,
      permissionsService: chatService?.deps?.permissionsService,
      chatViewModel: chatService?.chatViewModel,
      globalPreferences: chatService?.globalPreferences
    )
  }
}
