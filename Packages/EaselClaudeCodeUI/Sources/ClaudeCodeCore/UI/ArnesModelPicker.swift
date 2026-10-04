//
//  ArnesModelPicker.swift
//  ClaudeCodeUI
//

import SwiftUI

/// Inline model selector for the Arnes (OpenRouter) provider, shown in the
/// chat composer footer. Unlike the other providers' read-only badges this
/// is interactive: clicking opens a searchable popover of the OpenRouter
/// manifest with `Auto` pinned on top; the selection applies to the next
/// message, no trip to Settings required.
struct ArnesModelPickerBadge: View {
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @Environment(\.colorScheme) private var colorScheme

  /// Injected for tests; nil builds a catalog from the user's command and
  /// environment overrides at load time (Settings env vars like
  /// OPENROUTER_API_KEY must reach the `arnes models` fetch).
  let catalog: (any ArnesModelCatalogProviding)?

  @State private var isPresentingPicker = false
  @State private var models: [ArnesModelDescriptor] = []
  @State private var isLoadingModels = false
  @State private var searchText = ""

  init(catalog: (any ArnesModelCatalogProviding)? = nil) {
    self.catalog = catalog
  }

  var body: some View {
    Button {
      isPresentingPicker.toggle()
    } label: {
      badgeLabel
    }
    .buttonStyle(.plain)
    .help("OpenRouter model: \(selectedDisplayName). Click to change.")
    .accessibilityLabel("OpenRouter model")
    .accessibilityValue(selectedDisplayName)
    .popover(isPresented: $isPresentingPicker, arrowEdge: .bottom) {
      pickerContent
        .frame(width: 320, height: 380)
        .task { await loadModelsIfNeeded() }
    }
  }

  // MARK: - Badge

  private var badgeLabel: some View {
    HStack(spacing: 4) {
      Image(systemName: "cpu")
        .font(.system(size: 9, weight: .medium))

      Text(selectedDisplayName)
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
        .truncationMode(.middle)

      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 7, weight: .semibold))
    }
    .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
    .padding(.horizontal, 7)
    .padding(.vertical, 3)
    .frame(maxWidth: 180)
    .background(EaselChatRuntimeStyle.panelBackground(for: colorScheme), in: Capsule())
    .overlay {
      Capsule()
        .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
    }
    .contentShape(Capsule())
  }

  private var selectedDisplayName: String {
    let selected = globalPreferences.arnesModel.trimmingCharacters(in: .whitespacesAndNewlines)
    if selected.isEmpty || selected == ArnesModelDescriptor.autoIdentifier {
      return "Auto"
    }
    if selected.contains("/"), let leaf = selected.split(separator: "/").last {
      return String(leaf)
    }
    return selected
  }

  // MARK: - Popover

  private var pickerContent: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        TextField("Search models…", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 12))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      Divider()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          modelRow(.auto)

          if isLoadingModels, filteredModels.isEmpty {
            HStack(spacing: 6) {
              ProgressView()
                .controlSize(.small)
              Text("Loading models…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(10)
          }

          ForEach(filteredModels) { model in
            modelRow(model)
          }

          if !isLoadingModels, filteredModels.isEmpty, !searchText.isEmpty {
            Text("No models match “\(searchText)”. Press return to use it as a custom slug.")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .padding(10)
          }
        }
      }

      Divider()

      Text("Applies to your next message. Models from the OpenRouter manifest (tool-capable only).")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
    }
    .onSubmit(selectSearchTextAsCustomModel)
  }

  private var filteredModels: [ArnesModelDescriptor] {
    let available = models.filter { !$0.isAuto }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return available }
    return available.filter { $0.identifier.localizedCaseInsensitiveContains(query) }
  }

  @ViewBuilder
  private func modelRow(_ model: ArnesModelDescriptor) -> some View {
    let isSelected = isSelected(model)
    Button {
      select(model.identifier)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .semibold))
          .opacity(isSelected ? 1 : 0)

        VStack(alignment: .leading, spacing: 1) {
          Text(model.displayName)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .lineLimit(1)
            .truncationMode(.middle)

          if let detail = model.detail, !detail.isEmpty {
            Text(detail)
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func isSelected(_ model: ArnesModelDescriptor) -> Bool {
    let selected = globalPreferences.arnesModel.trimmingCharacters(in: .whitespacesAndNewlines)
    if model.isAuto {
      return selected.isEmpty || selected == ArnesModelDescriptor.autoIdentifier
    }
    return selected == model.identifier
  }

  private func select(_ identifier: String) {
    if globalPreferences.arnesModel != identifier {
      globalPreferences.arnesModel = identifier
    }
    isPresentingPicker = false
    searchText = ""
  }

  /// Pressing return with a non-matching query treats it as an exact slug —
  /// the escape hatch for models not in the cached manifest.
  private func selectSearchTextAsCustomModel() {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    if let exact = filteredModels.first(where: { $0.identifier.caseInsensitiveCompare(query) == .orderedSame }) {
      select(exact.identifier)
      return
    }
    if filteredModels.isEmpty {
      select(query)
    }
  }

  private func loadModelsIfNeeded() async {
    guard models.isEmpty, !isLoadingModels else { return }
    isLoadingModels = true
    let catalog = self.catalog ?? ArnesModelCatalog(
      commandRunner: ArnesModelsCommandRunner(
        commandOverride: globalPreferences.arnesCommand,
        environmentOverrides: globalPreferences.arnesEnvironmentVariables
      )
    )
    models = await catalog.availableModels()
    isLoadingModels = false
  }
}
