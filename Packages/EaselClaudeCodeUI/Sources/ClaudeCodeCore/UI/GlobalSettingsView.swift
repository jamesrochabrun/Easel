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
