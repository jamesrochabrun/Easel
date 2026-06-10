//
//  GlobalSettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI
import AppKit

struct GlobalSettingsView: View {
  let uiConfiguration: UIConfiguration
  let chatViewModel: ChatViewModel?
  let mcpToolsDiscovery: MCPToolsDiscoveryService
  let codexModelCatalog: any CodexModelCatalogProviding

  init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    codexModelCatalog: any CodexModelCatalogProviding = CodexModelCacheCatalog()
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.codexModelCatalog = codexModelCatalog
  }
  
  // MARK: - Constants
  private enum Layout {
    static let windowWidth: CGFloat = 700
    static let windowHeight: CGFloat = 620
    static let textEditorHeight: CGFloat = 100
  }

  // MARK: - Properties
  @Environment(\.dismiss) private var dismiss
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @State private var codexModels: [CodexModelDescriptor] = []

  // MARK: - Body
  var body: some View {
    preferencesView
    .frame(width: Layout.windowWidth, height: Layout.windowHeight)
    .background(Color(NSColor.windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          dismiss()
        }
      }
    }
    .onAppear {
      ensureCodexProvider()
      refreshCodexModels()
    }
  }
  
  // MARK: - Preferences View
  private var preferencesView: some View {
    return VStack(spacing: 0) {
      Form {
        providerConfigurationSection
      }
      .formStyle(.grouped)

      Divider()

      // Version footer
      HStack {
        Spacer()
        Text(VersionProvider.formattedVersion)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(Color(NSColor.windowBackgroundColor))
    }
  }
  
  // MARK: - Configuration Sections
  private var providerConfigurationSection: some View {
    return Section("Assistant Configuration") {
      codexConfigurationRow
      if uiConfiguration.showSystemPromptFields {
        systemPromptRow
      }
    }
  }

  @ViewBuilder
  private var codexConfigurationRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      CodexModelPickerRow(
        preferences: globalPreferences,
        models: codexModels,
        onRefresh: refreshCodexModels
      )

      Divider()

      Text("Codex CLI")
      Text("Command: codex")
        .font(.system(.body, design: .monospaced))
      Text("Detected from ~/.codex/local/codex, nvm, Homebrew, or PATH.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
  
  // MARK: - Configuration Rows
  @ViewBuilder
  private var systemPromptRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("System Prompt")
      promptTextEditor(text: $preferences.systemPrompt)
    }
  }
  
  // MARK: - Helper Methods
  private func ensureCodexProvider() {
    if globalPreferences.chatProvider != .codex {
      if let chatViewModel {
        chatViewModel.switchProvider(to: .codex)
      } else {
        globalPreferences.chatProvider = .codex
      }
    }
  }

  private func refreshCodexModels() {
    Task {
      let homeDirectory = NSHomeDirectory()
      let models = await codexModelCatalog.availableModels(homeDirectory: homeDirectory)
      codexModels = models

      let selected = globalPreferences.codexModel.trimmingCharacters(in: .whitespacesAndNewlines)
      if selected.isEmpty {
        globalPreferences.codexModel = codexModelCatalog.defaultModelIdentifier(homeDirectory: homeDirectory)
      }
    }
  }

  private func promptTextEditor(text: Binding<String>) -> some View {
    TextEditor(text: text)
      .font(.system(.body, design: .monospaced))
      .frame(height: Layout.textEditorHeight)
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      )
  }

}


#Preview {
  GlobalSettingsView()
    .environment(AppearanceSettings())
}
