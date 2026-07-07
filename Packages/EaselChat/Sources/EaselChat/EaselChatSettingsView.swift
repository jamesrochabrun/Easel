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
  @State private var showOnDeviceModels = false

  public init(chatService: ChatService? = nil) {
    self.chatService = chatService
  }

  public var body: some View {
    VStack(spacing: 0) {
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
        mcpToolsDiscovery: chatService?.mcpToolsDiscoveryService
      )

      if let chatService {
        Divider()
        DisclosureGroup("On-Device Models (MLX)", isExpanded: $showOnDeviceModels) {
          MLXModelManagerView(manager: chatService.onDeviceModelManager)
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      }
    }
    .tint(EaselDesignSystem.Palette.accent)
  }
}
