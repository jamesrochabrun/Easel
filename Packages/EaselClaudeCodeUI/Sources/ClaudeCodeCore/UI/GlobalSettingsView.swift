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
  /// Optional extra content rendered inside the Form for the `.api` provider
  /// (e.g. the embedding app's on-device MLX model manager). Injected as a
  /// closure so ClaudeCodeCore need not link the MLX package.
  let apiExtraContent: (() -> AnyView)?

  init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    codexModelCatalog: any CodexModelCatalogProviding = CodexModelCacheCatalog(),
    claudeModelCatalog: any ClaudeModelCatalogProviding = ClaudeModelCatalog(),
    credentialStore: any CredentialStore = KeychainCredentialStore(),
    apiModelCatalog: any APIModelCatalogProviding = APIModelCatalog(),
    apiExtraContent: (() -> AnyView)? = nil
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.codexModelCatalog = codexModelCatalog
    self.claudeModelCatalog = claudeModelCatalog
    self.credentialStore = credentialStore
    self.apiModelCatalog = apiModelCatalog
    self.apiExtraContent = apiExtraContent
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
  // Editable drafts for the selected endpoint, loaded on selection change.
  @State private var apiKeyDraft = ""
  @State private var serverURLDraft = ""
  @State private var draftProfileId = ""
  @State private var connectionTest: ConnectionTestState = .idle

  private enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success(Int)
    case failure(String)
  }

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
        loadEndpointDrafts()
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
    .onReceive(NotificationCenter.default.publisher(for: .agentInstalledModelsDidChange)) { _ in
      // A local model finished downloading (or was deleted) — refresh the
      // picker so it shows up immediately.
      if globalPreferences.chatProvider == .api {
        refreshAPIModels()
      }
    }
  }
  
  // MARK: - Preferences View
  private var preferencesView: some View {
    return VStack(spacing: 0) {
      Form {
        providerConfigurationSection

        if globalPreferences.chatProvider == .api {
          apiEndpointSection
          apiModelSection
          if selectedAPIProfile?.kind == .mlxLocal, let apiExtraContent {
            Section("On-Device Models") {
              apiExtraContent()
            }
          }
          apiAdvancedSection
        }
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
        // The Local / API provider renders its own dedicated sections below.
        EmptyView()
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

  // MARK: - Local / API sections

  @ViewBuilder
  private var apiEndpointSection: some View {
    @Bindable var preferences = globalPreferences
    Section("Provider") {
      Picker("Provider", selection: $preferences.selectedAPIProfileId) {
        let grouped = groupedAPIProfiles
        if !grouped.local.isEmpty {
          Section("On your Mac") {
            ForEach(grouped.local) { Text($0.name).tag($0.id) }
          }
        }
        if !grouped.hosted.isEmpty {
          Section("Hosted API") {
            ForEach(grouped.hosted) { Text($0.name).tag($0.id) }
          }
        }
        if !grouped.custom.isEmpty {
          Section("Custom") {
            ForEach(grouped.custom) { Text($0.name).tag($0.id) }
          }
        }
      }
      .onChange(of: preferences.selectedAPIProfileId) { _, _ in
        preferences.apiModel = selectedAPIProfile?.defaultModel ?? ""
        apiModels = []
        connectionTest = .idle
        loadEndpointDrafts()
        refreshAPIModels()
      }

      // Config that makes sense for the selected provider kind.
      if let profile = selectedAPIProfile {
        switch profile.category {
        case .hosted:
          hostedProviderConfig(for: profile)
        case .localServer:
          localServerConfig
        case .onDevice:
          Text("Runs on this Mac via MLX — no server or API key needed. Download and choose a model below.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      endpointManagementRow
    }
  }

  @ViewBuilder
  private func hostedProviderConfig(for profile: EndpointProfile) -> some View {
    LabeledContent("Endpoint") {
      Text(profile.baseURL)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    SecureField("API Key", text: $apiKeyDraft, prompt: Text("Paste your \(profile.name) API key"))
      .textFieldStyle(.roundedBorder)
      .onChange(of: apiKeyDraft) { _, _ in persistKeyDraft() }
    connectionTestRow
    Text("Your key is stored in the macOS Keychain, never in plain text.")
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var localServerConfig: some View {
    TextField("Server URL", text: $serverURLDraft, prompt: Text("http://localhost:11434"))
      .textFieldStyle(.roundedBorder)
      .font(.system(.body, design: .monospaced))
      .onChange(of: serverURLDraft) { _, _ in persistURLDraft() }
    connectionTestRow
    Text("Make sure the server is running before you start a chat.")
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var connectionTestRow: some View {
    HStack(spacing: 8) {
      Button("Test Connection") { testConnection() }
        .disabled(connectionTest == .testing)

      switch connectionTest {
      case .idle:
        EmptyView()
      case .testing:
        ProgressView().controlSize(.small)
      case .success(let count):
        Label("\(count) model\(count == 1 ? "" : "s") available", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.caption)
      case .failure(let message):
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .font(.caption)
          .lineLimit(2)
      }
    }
  }

  @ViewBuilder
  private var endpointManagementRow: some View {
    HStack {
      Button("Add Custom Endpoint", systemImage: "plus") {
        apiEditorContext = APIProfileEditorContext(
          profile: EndpointProfile(
            id: UUID().uuidString,
            name: "",
            kind: .openAICompatible,
            baseURL: "",
            requiresAPIKey: true
          ),
          isNew: true
        )
      }

      Spacer()

      if let profile = selectedAPIProfile, !profile.isPreset {
        Button("Edit", systemImage: "pencil") {
          apiEditorContext = APIProfileEditorContext(profile: profile, isNew: false)
        }
        Button("Remove", systemImage: "trash", role: .destructive) {
          isConfirmingProfileDeletion = true
        }
        .confirmationDialog(
          "Remove “\(selectedAPIProfile?.name ?? "")”? Its stored API key is deleted from the Keychain.",
          isPresented: $isConfirmingProfileDeletion
        ) {
          Button("Remove", role: .destructive) { deleteSelectedAPIProfile() }
        }
      }
    }
    .buttonStyle(.borderless)
  }

  @ViewBuilder
  private var apiModelSection: some View {
    Section("Model") {
      HStack {
        if apiModels.isEmpty {
          TextField("Model", text: selectedProfileModelBinding, prompt: Text("e.g. qwen2.5-coder:7b"))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
        } else {
          Picker("Model", selection: selectedProfileModelBinding) {
            let current = selectedProfileModelBinding.wrappedValue
            if !current.isEmpty, !apiModels.contains(where: { $0.id == current }) {
              Text(current).tag(current)
            }
            ForEach(apiModels) { model in
              Text(model.displayName ?? model.id).tag(model.id)
            }
          }
          .labelsHidden()
        }

        Button("Refresh Models", systemImage: "arrow.clockwise") { refreshAPIModels() }
          .labelStyle(.iconOnly)
      }

      if let apiModelsStatus {
        Text(apiModelsStatus)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Pick a model with strong tool-calling. Qwen coder models are a good default.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var apiAdvancedSection: some View {
    @Bindable var preferences = globalPreferences
    Section("Advanced") {
      Stepper("Maximum tool-use turns: \(preferences.apiMaxTurns)", value: $preferences.apiMaxTurns, in: 5...50)
      Text("How many tool-use rounds one message may take before stopping.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Local / API helpers

  private var groupedAPIProfiles: (local: [EndpointProfile], hosted: [EndpointProfile], custom: [EndpointProfile]) {
    var local: [EndpointProfile] = []
    var hosted: [EndpointProfile] = []
    var custom: [EndpointProfile] = []
    for profile in globalPreferences.apiEndpointProfiles {
      if !profile.isPreset {
        custom.append(profile)
      } else if profile.category == .hosted {
        hosted.append(profile)
      } else {
        local.append(profile)
      }
    }
    return (local, hosted, custom)
  }

  private func loadEndpointDrafts() {
    let id = globalPreferences.selectedAPIProfileId
    draftProfileId = id
    apiKeyDraft = (try? credentialStore.apiKey(for: id)) ?? ""
    serverURLDraft = selectedAPIProfile?.baseURL ?? ""
  }

  private func persistKeyDraft() {
    guard !draftProfileId.isEmpty else { return }
    try? credentialStore.setAPIKey(apiKeyDraft.isEmpty ? nil : apiKeyDraft, for: draftProfileId)
  }

  private func persistURLDraft() {
    guard !draftProfileId.isEmpty,
          let index = globalPreferences.apiEndpointProfiles.firstIndex(where: { $0.id == draftProfileId })
    else { return }
    globalPreferences.apiEndpointProfiles[index].baseURL = serverURLDraft
  }

  private func testConnection() {
    guard let profile = selectedAPIProfile else { return }
    connectionTest = .testing
    Task {
      do {
        let key = apiKeyDraft.isEmpty ? (try? credentialStore.apiKey(for: profile.id)) : apiKeyDraft
        let models = try await apiModelCatalog.availableModels(profile: profile, apiKey: key)
        connectionTest = .success(models.count)
        apiModels = models
        apiModelsStatus = models.isEmpty ? "No models reported by the endpoint — type a model id." : nil
      } catch {
        connectionTest = .failure(error.localizedDescription)
      }
    }
  }

  private var selectedAPIProfile: EndpointProfile? {
    globalPreferences.apiEndpointProfiles.first { $0.id == globalPreferences.selectedAPIProfileId }
      ?? globalPreferences.apiEndpointProfiles.first
  }

  /// The model is stored on the selected endpoint profile so each endpoint
  /// remembers its own model across relaunches and endpoint switches.
  private var selectedProfileModelBinding: Binding<String> {
    Binding(
      get: { selectedAPIProfile?.defaultModel ?? "" },
      set: { setSelectedProfileModel($0) }
    )
  }

  private func setSelectedProfileModel(_ modelId: String) {
    guard let profile = selectedAPIProfile,
          let index = globalPreferences.apiEndpointProfiles.firstIndex(where: { $0.id == profile.id })
    else { return }
    globalPreferences.apiEndpointProfiles[index].defaultModel = modelId
    // Mirror to the legacy field so existing readers stay in sync.
    globalPreferences.apiModel = modelId
  }

  private func saveAPIProfile(_ profile: EndpointProfile, isNew: Bool) {
    if isNew {
      globalPreferences.apiEndpointProfiles.append(profile)
    } else if let index = globalPreferences.apiEndpointProfiles.firstIndex(where: { $0.id == profile.id }) {
      globalPreferences.apiEndpointProfiles[index] = profile
    }
    globalPreferences.selectedAPIProfileId = profile.id
    apiModels = []
    connectionTest = .idle
    loadEndpointDrafts()
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
    connectionTest = .idle
    loadEndpointDrafts()
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
        // Default this endpoint to its first model only if it has none chosen.
        if (selectedAPIProfile?.defaultModel ?? "").isEmpty, let first = models.first {
          setSelectedProfileModel(first.id)
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
