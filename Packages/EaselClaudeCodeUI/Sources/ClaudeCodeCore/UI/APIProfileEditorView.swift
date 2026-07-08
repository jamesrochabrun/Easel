//
//  APIProfileEditorView.swift
//  ClaudeCodeUI
//

import AgentHarness
import SwiftUI

/// Sheet context for adding or editing a Local / API endpoint profile.
struct APIProfileEditorContext: Identifiable {
  var profile: EndpointProfile
  var isNew: Bool

  var id: String { profile.id }
}

/// Add/edit sheet for one `EndpointProfile`. The API key is written straight
/// to the credential store on save and never touches preferences JSON.
struct APIProfileEditorView: View {
  private enum ConnectionTest: Equatable {
    case idle
    case testing
    case success(modelCount: Int)
    case failure(String)
  }

  let context: APIProfileEditorContext
  let credentialStore: any CredentialStore
  let modelCatalog: any APIModelCatalogProviding
  let onSave: (EndpointProfile) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var name: String
  @State private var kind: EndpointProfile.Kind
  @State private var baseURL: String
  @State private var requiresAPIKey: Bool
  @State private var apiKey = ""
  @State private var supportsStreamingToolCalls: Bool
  @State private var supportsParallelToolCalls: Bool
  @State private var supportsVision: Bool
  @State private var contextWindowTokens: Int
  @State private var connectionTest: ConnectionTest = .idle

  init(
    context: APIProfileEditorContext,
    credentialStore: any CredentialStore,
    modelCatalog: any APIModelCatalogProviding,
    onSave: @escaping (EndpointProfile) -> Void
  ) {
    self.context = context
    self.credentialStore = credentialStore
    self.modelCatalog = modelCatalog
    self.onSave = onSave

    let profile = context.profile
    _name = State(initialValue: profile.name)
    _kind = State(initialValue: profile.kind)
    _baseURL = State(initialValue: profile.baseURL)
    _requiresAPIKey = State(initialValue: profile.requiresAPIKey)
    _supportsStreamingToolCalls = State(initialValue: profile.capabilities.supportsStreamingToolCalls)
    _supportsParallelToolCalls = State(initialValue: profile.capabilities.supportsParallelToolCalls)
    _supportsVision = State(initialValue: profile.capabilities.supportsVision)
    _contextWindowTokens = State(initialValue: profile.capabilities.contextWindowTokens)
  }

  var body: some View {
    VStack(spacing: 0) {
      Form {
        Section("Endpoint") {
          TextField("Name", text: $name)

          Picker("Kind", selection: $kind) {
            Text("OpenAI-compatible").tag(EndpointProfile.Kind.openAICompatible)
            Text("Ollama (native)").tag(EndpointProfile.Kind.ollamaNative)
            Text("On-device MLX").tag(EndpointProfile.Kind.mlxLocal)
          }

          if kind == .mlxLocal {
            Text("Models run on this Mac via MLX — no server or API key needed.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            TextField("Base URL", text: $baseURL, prompt: Text("http://localhost:11434"))
              .font(.system(.body, design: .monospaced))

            Toggle("Requires API key", isOn: $requiresAPIKey)

            if requiresAPIKey {
              SecureField("API key", text: $apiKey, prompt: Text("Stored in the Keychain"))
            }

            connectionTestRow
          }
        }

        if kind != .mlxLocal {
          Section("Capabilities") {
            Toggle("Streams tool calls reliably", isOn: $supportsStreamingToolCalls)
            Text("Turn off for servers that mishandle streamed tool calls — responses then arrive unstreamed whenever tools are active.")
              .font(.caption)
              .foregroundStyle(.secondary)

            Toggle("Parallel tool calls", isOn: $supportsParallelToolCalls)
            Toggle("Vision (image input)", isOn: $supportsVision)

            TextField("Context window (tokens)", value: $contextWindowTokens, format: .number.grouping(.never))
          }
        }
      }
      .formStyle(.grouped)

      Divider()

      HStack {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        Spacer()
        Button("Save") {
          save()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      .padding()
    }
    .frame(width: 480, height: 520)
    .task {
      guard !context.isNew, requiresAPIKey else { return }
      apiKey = (try? credentialStore.apiKey(for: context.profile.id)) ?? ""
    }
  }

  @ViewBuilder
  private var connectionTestRow: some View {
    HStack {
      Button("Test Connection") {
        testConnection()
      }
      .disabled(connectionTest == .testing || baseURL.trimmingCharacters(in: .whitespaces).isEmpty)

      switch connectionTest {
      case .idle:
        EmptyView()
      case .testing:
        ProgressView()
          .controlSize(.small)
      case .success(let modelCount):
        Label("\(modelCount) model\(modelCount == 1 ? "" : "s") available", systemImage: "checkmark.circle.fill")
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

  private var editedProfile: EndpointProfile {
    var profile = context.profile
    profile.name = name.trimmingCharacters(in: .whitespaces)
    profile.kind = kind
    profile.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
    profile.requiresAPIKey = kind == .mlxLocal ? false : requiresAPIKey
    profile.capabilities.supportsStreamingToolCalls = supportsStreamingToolCalls
    profile.capabilities.supportsParallelToolCalls = supportsParallelToolCalls
    profile.capabilities.supportsVision = supportsVision
    profile.capabilities.contextWindowTokens = max(2_048, contextWindowTokens)
    return profile
  }

  private func testConnection() {
    let profile = editedProfile
    let key = apiKey.isEmpty ? nil : apiKey
    connectionTest = .testing
    Task {
      do {
        let models = try await modelCatalog.availableModels(profile: profile, apiKey: key)
        connectionTest = .success(modelCount: models.count)
      } catch {
        connectionTest = .failure(error.localizedDescription)
      }
    }
  }

  private func save() {
    let profile = editedProfile
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
    try? credentialStore.setAPIKey(
      profile.requiresAPIKey && !trimmedKey.isEmpty ? trimmedKey : nil,
      for: profile.id
    )
    onSave(profile)
    dismiss()
  }
}
