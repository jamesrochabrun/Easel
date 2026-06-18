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
  let claudeModelCatalog: any ClaudeModelCatalogProviding

  init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    codexModelCatalog: any CodexModelCatalogProviding = CodexModelCacheCatalog(),
    claudeModelCatalog: any ClaudeModelCatalogProviding = ClaudeModelCatalog()
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.codexModelCatalog = codexModelCatalog
    self.claudeModelCatalog = claudeModelCatalog
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
  @State private var claudeModels: [ClaudeModelDescriptor] = []

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
      if globalPreferences.chatProvider == .codex {
        refreshCodexModels()
      } else {
        refreshClaudeModels()
      }
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
      providerPickerRow

      if globalPreferences.chatProvider == .codex {
        codexConfigurationRow
      } else {
        claudeConfigurationRow
      }

      if uiConfiguration.showSystemPromptFields {
        systemPromptRow
      }
    }
  }

  @ViewBuilder
  private var providerPickerRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Picker("Provider", selection: $preferences.chatProvider) {
        ForEach(ChatProvider.allCases) { provider in
          Text(provider.displayName)
            .tag(provider)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: preferences.chatProvider) { _, provider in
        chatViewModel?.switchProvider(to: provider)
        if provider == .codex {
          refreshCodexModels()
        } else {
          refreshClaudeModels()
        }
      }

      Text("New chats use this provider. Existing saved sessions resume with their original provider.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private var codexConfigurationRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 16) {
      CodexModelPickerRow(
        preferences: globalPreferences,
        models: codexModels,
        onRefresh: refreshCodexModels
      )

      Divider()

      // Command
      VStack(alignment: .leading, spacing: 6) {
        Text("Command")
          .font(.caption)
          .foregroundColor(.secondary)
        TextField("codex", text: $preferences.codexCommand)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
        Text("Leave empty to auto-detect from ~/.codex/local/codex, nvm, Homebrew, or PATH.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Extra arguments
      VStack(alignment: .leading, spacing: 6) {
        Text("Extra arguments")
          .font(.caption)
          .foregroundColor(.secondary)
        TextField("e.g. --api-mode enterprise", text: $preferences.codexExtraArgs)
          .textFieldStyle(.roundedBorder)
        Text("Arguments applied to each CLI launch.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Environment variables
      VStack(alignment: .leading, spacing: 6) {
        Text("Environment variables")
          .font(.caption)
          .foregroundColor(.secondary)
        CodexEnvironmentVariablesEditor(variables: $preferences.codexEnvironmentVariables)
        Text("Injected into the Codex CLI process on each launch.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  @ViewBuilder
  private var claudeConfigurationRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 16) {
      ClaudeModelPickerRow(
        preferences: globalPreferences,
        models: claudeModels,
        onRefresh: refreshClaudeModels
      )

      settingsMultilineEditor(
        title: "Allowed Tools",
        placeholder: "One pattern per line or comma-separated, e.g. Bash(npm *)\nRead\nEdit",
        text: $preferences.claudeAllowedTools
      )

      settingsMultilineEditor(
        title: "Denied Tools",
        placeholder: "One pattern per line or comma-separated, e.g. Bash(rm -rf *)",
        text: $preferences.claudeDisallowedTools
      )

      Divider()

      settingsField("Command") {
        TextField("claude", text: $preferences.claudeCommand)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .onChange(of: preferences.claudeCommand) { _, _ in
            chatViewModel?.updateClaudeCommand(from: preferences)
          }
        Text("Claude runs in bypass-permissions mode for embedded chat.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      settingsField("Executable path") {
        TextField("Optional absolute path", text: $preferences.claudePath)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .onChange(of: preferences.claudePath) { _, _ in
            chatViewModel?.updateClaudeCommand(from: preferences)
          }
        Text("Leave empty to resolve the command from PATH.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
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

  private func refreshClaudeModels() {
    Task {
      claudeModels = await claudeModelCatalog.availableModels()
    }
  }

  private func settingsField<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func settingsMultilineEditor(
    title: String,
    placeholder: String,
    text: Binding<String>
  ) -> some View {
    settingsField(title) {
      MultilineSettingsEditor(text: text, placeholder: placeholder)
      Text("Use one tool pattern per line, or separate multiple values with commas.")
        .font(.caption)
        .foregroundColor(.secondary)
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

private struct MultilineSettingsEditor: View {
  @Binding var text: String
  let placeholder: String
  @FocusState private var isFocused: Bool

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .scrollContentBackground(.hidden)
        .focused($isFocused)
        .font(.system(size: 13))
        .frame(minHeight: 84)
        .padding(6)

      if text.isEmpty {
        Text(placeholder)
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .padding(.horizontal, 11)
          .padding(.vertical, 14)
          .allowsHitTesting(false)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.textBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isFocused ? Color.accentColor.opacity(0.55) : Color(NSColor.separatorColor), lineWidth: 1)
    )
  }
}


// MARK: - Environment Variables Editor

/// A simple key/value editor backed by a `[String: String]` binding. Maintains a
/// stable row order locally (dictionaries are unordered) and writes back the
/// non-empty rows whenever an edit occurs.
struct CodexEnvironmentVariablesEditor: View {
  @Binding var variables: [String: String]

  private struct Row: Identifiable {
    let id = UUID()
    var key: String
    var value: String
  }

  @State private var rows: [Row] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach($rows) { $row in
        HStack(spacing: 8) {
          TextField("NAME", text: $row.key)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: 200)
            .onChange(of: row.key) { commit() }

          Text("=")
            .foregroundColor(.secondary)

          TextField("value", text: $row.value)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .onChange(of: row.value) { commit() }

          Button {
            rows.removeAll { $0.id == row.id }
            commit()
          } label: {
            Image(systemName: "minus.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .help("Remove variable")
        }
      }

      Button {
        rows.append(Row(key: "", value: ""))
      } label: {
        Label("Add variable", systemImage: "plus.circle")
      }
      .buttonStyle(.link)
    }
    .onAppear(perform: syncFromBinding)
  }

  private func syncFromBinding() {
    guard rows.isEmpty else { return }
    rows = variables
      .sorted { $0.key < $1.key }
      .map { Row(key: $0.key, value: $0.value) }
  }

  private func commit() {
    var result: [String: String] = [:]
    for row in rows {
      let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !key.isEmpty else { continue }
      result[key] = row.value
    }
    variables = result
  }
}

#Preview {
  GlobalSettingsView()
    .environment(AppearanceSettings())
}
