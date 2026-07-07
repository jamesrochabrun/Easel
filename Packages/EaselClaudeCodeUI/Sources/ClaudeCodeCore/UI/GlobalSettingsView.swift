//
//  GlobalSettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import AgentHarness
import SwiftUI
import AppKit

struct GlobalSettingsView: View {
  let uiConfiguration: UIConfiguration
  let chatViewModel: ChatViewModel?
  let mcpToolsDiscovery: MCPToolsDiscoveryService
  let codexModelCatalog: any CodexModelCatalogProviding
  let claudeModelCatalog: any ClaudeModelCatalogProviding
  let credentialStore: any CredentialStore
  let apiModelCatalog: any APIModelCatalogProviding

  init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    codexModelCatalog: any CodexModelCatalogProviding = CodexModelCacheCatalog(),
    claudeModelCatalog: any ClaudeModelCatalogProviding = ClaudeModelCatalog(),
    credentialStore: any CredentialStore = KeychainCredentialStore(),
    apiModelCatalog: any APIModelCatalogProviding = APIModelCatalog()
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.codexModelCatalog = codexModelCatalog
    self.claudeModelCatalog = claudeModelCatalog
    self.credentialStore = credentialStore
    self.apiModelCatalog = apiModelCatalog
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
  @State private var apiModels: [AgentModelInfo] = []
  @State private var apiModelsStatus: String?
  @State private var apiEditorContext: APIProfileEditorContext?
  @State private var isConfirmingProfileDeletion = false

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
      switch globalPreferences.chatProvider {
      case .codex:
        refreshCodexModels()
      case .claude:
        refreshClaudeModels()
      case .api:
        refreshAPIModels()
      }
    }
    .sheet(item: $apiEditorContext) { context in
      APIProfileEditorView(
        context: context,
        credentialStore: credentialStore,
        modelCatalog: apiModelCatalog
      ) { profile in
        saveAPIProfile(profile, isNew: context.isNew)
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

      switch globalPreferences.chatProvider {
      case .codex:
        codexConfigurationRow
      case .claude:
        claudeConfigurationRow
      case .api:
        apiConfigurationRow
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
        switch provider {
        case .codex:
          refreshCodexModels()
        case .claude:
          refreshClaudeModels()
        case .api:
          refreshAPIModels()
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
  private var apiConfigurationRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 16) {
      // Endpoint profile selection + management
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Picker("Endpoint", selection: $preferences.selectedAPIProfileId) {
            ForEach(preferences.apiEndpointProfiles) { profile in
              Text(profile.name).tag(profile.id)
            }
          }
          .onChange(of: preferences.selectedAPIProfileId) { _, _ in
            apiModels = []
            refreshAPIModels()
          }

          Button("Edit Endpoint", systemImage: "pencil") {
            if let profile = selectedAPIProfile {
              apiEditorContext = APIProfileEditorContext(profile: profile, isNew: false)
            }
          }
          .labelStyle(.iconOnly)

          Button("Add Endpoint", systemImage: "plus") {
            apiEditorContext = APIProfileEditorContext(
              profile: EndpointProfile(
                id: UUID().uuidString,
                name: "",
                kind: .openAICompatible,
                baseURL: ""
              ),
              isNew: true
            )
          }
          .labelStyle(.iconOnly)

          Button("Delete Endpoint", systemImage: "trash", role: .destructive) {
            isConfirmingProfileDeletion = true
          }
          .labelStyle(.iconOnly)
          .disabled(preferences.apiEndpointProfiles.count <= 1)
          .confirmationDialog(
            "Delete “\(selectedAPIProfile?.name ?? "")”? Its stored API key is removed from the Keychain.",
            isPresented: $isConfirmingProfileDeletion
          ) {
            Button("Delete", role: .destructive) {
              deleteSelectedAPIProfile()
            }
          }
        }

        if let profile = selectedAPIProfile {
          Text(profile.kind == .mlxLocal ? "Runs on this Mac via MLX." : profile.baseURL)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Divider()

      // Model selection
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          if apiModels.isEmpty {
            TextField("Model", text: $preferences.apiModel, prompt: Text("e.g. qwen3-coder:30b"))
              .textFieldStyle(.roundedBorder)
              .font(.system(.body, design: .monospaced))
          } else {
            Picker("Model", selection: $preferences.apiModel) {
              if !preferences.apiModel.isEmpty,
                 !apiModels.contains(where: { $0.id == preferences.apiModel }) {
                Text(preferences.apiModel).tag(preferences.apiModel)
              }
              ForEach(apiModels) { model in
                Text(model.id).tag(model.id)
              }
            }
          }

          Button("Refresh Models", systemImage: "arrow.clockwise") {
            refreshAPIModels()
          }
          .labelStyle(.iconOnly)
        }

        if let apiModelsStatus {
          Text(apiModelsStatus)
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Text("Pick a model that handles tool calling well (Qwen coder models are a good local default).")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Divider()

      Stepper(
        "Max agent turns: \(preferences.apiMaxTurns)",
        value: $preferences.apiMaxTurns,
        in: 5...50
      )
      Text("How many tool-use rounds one message may take before stopping.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var selectedAPIProfile: EndpointProfile? {
    globalPreferences.apiEndpointProfiles.first { $0.id == globalPreferences.selectedAPIProfileId }
      ?? globalPreferences.apiEndpointProfiles.first
  }

  private func saveAPIProfile(_ profile: EndpointProfile, isNew: Bool) {
    if isNew {
      globalPreferences.apiEndpointProfiles.append(profile)
    } else if let index = globalPreferences.apiEndpointProfiles.firstIndex(where: { $0.id == profile.id }) {
      globalPreferences.apiEndpointProfiles[index] = profile
    }
    globalPreferences.selectedAPIProfileId = profile.id
    apiModels = []
    refreshAPIModels()
  }

  private func deleteSelectedAPIProfile() {
    guard globalPreferences.apiEndpointProfiles.count > 1,
          let profile = selectedAPIProfile
    else { return }
    try? credentialStore.setAPIKey(nil, for: profile.id)
    globalPreferences.apiEndpointProfiles.removeAll { $0.id == profile.id }
    globalPreferences.selectedAPIProfileId = globalPreferences.apiEndpointProfiles.first?.id ?? ""
    apiModels = []
    refreshAPIModels()
  }

  private func refreshAPIModels() {
    guard let profile = selectedAPIProfile else { return }
    apiModelsStatus = "Loading models…"
    Task {
      do {
        let key = try? credentialStore.apiKey(for: profile.id)
        let models = try await apiModelCatalog.availableModels(profile: profile, apiKey: key)
        apiModels = models
        apiModelsStatus = models.isEmpty ? "No models reported by the endpoint — type a model id." : nil
        if globalPreferences.apiModel.isEmpty, let first = models.first {
          globalPreferences.apiModel = first.id
        }
      } catch {
        apiModels = []
        apiModelsStatus = "Could not list models: \(error.localizedDescription)"
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
