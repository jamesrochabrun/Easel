//
//  ClaudeCodeGlobalSettingsSceneView.swift
//  ClaudeCodeUI
//

import SwiftUI

public struct ClaudeCodeGlobalSettingsSceneView: View {
  private let uiConfiguration: UIConfiguration
  private let chatViewModel: ChatViewModel?
  private let providedGlobalPreferences: GlobalPreferencesStorage?
  private let providedMCPToolsDiscovery: MCPToolsDiscoveryService?

  @State private var ownedGlobalPreferences = GlobalPreferencesStorage()
  @State private var ownedMCPToolsDiscovery = MCPToolsDiscoveryService()

  public init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    globalPreferences: GlobalPreferencesStorage? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService? = nil
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.providedGlobalPreferences = globalPreferences
    self.providedMCPToolsDiscovery = mcpToolsDiscovery
  }

  public var body: some View {
    GlobalSettingsView(
      uiConfiguration: uiConfiguration,
      chatViewModel: chatViewModel,
      mcpToolsDiscovery: activeMCPToolsDiscovery
    )
    .environment(activeGlobalPreferences)
  }

  private var activeGlobalPreferences: GlobalPreferencesStorage {
    providedGlobalPreferences ?? ownedGlobalPreferences
  }

  private var activeMCPToolsDiscovery: MCPToolsDiscoveryService {
    providedMCPToolsDiscovery ?? ownedMCPToolsDiscovery
  }
}
