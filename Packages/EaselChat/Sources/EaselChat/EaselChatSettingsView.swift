//
//  EaselChatSettingsView.swift
//  EaselChat
//

import AgentProviderMLX
import ClaudeCodeCore
import EaselKit
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
        useMaterialInputBackground: false,
        showWelcomeRow: false
      ),
      chatViewModel: chatService?.chatViewModel,
      globalPreferences: chatService?.globalPreferences,
      mcpToolsDiscovery: chatService?.mcpToolsDiscoveryService,
      apiModelCatalog: chatService?.apiModelCatalog,
      apiExtraContent: chatService.map { service in
        { AnyView(MLXModelManagerView(manager: service.onDeviceModelManager)) }
      }
    )
    .tint(EaselDesignSystem.Palette.accent)
  }
}
