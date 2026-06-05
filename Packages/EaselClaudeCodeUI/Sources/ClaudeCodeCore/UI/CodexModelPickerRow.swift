//
//  CodexModelPickerRow.swift
//  ClaudeCodeUI
//

import SwiftUI

struct CodexModelPickerRow: View {
  @Bindable var preferences: GlobalPreferencesStorage
  @State private var isShowingModelOptions = false
  @State private var isHoveringModelSelector = false

  let models: [CodexModelDescriptor]
  let onRefresh: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Codex Model")

      HStack(spacing: 8) {
        Button {
          isShowingModelOptions.toggle()
        } label: {
          selectedModelLabel
        }
        .buttonStyle(.plain)
        .onHover { isHoveringModelSelector = $0 }
        .popover(isPresented: $isShowingModelOptions, arrowEdge: .bottom) {
          modelOptionsPopover
        }
        .accessibilityLabel("Codex Model")
        .accessibilityValue(selectedModelAccessibilityValue)

        Button(action: onRefresh) {
          Image(systemName: "arrow.clockwise")
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.bordered)
        .help("Refresh Codex model list")
      }
    }
  }

  private var modelOptionsPopover: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(modelOptions) { model in
          Button {
            preferences.codexModel = model.slug
            isShowingModelOptions = false
          } label: {
            modelOptionRow(for: model)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(6)
    }
    .frame(width: 360)
    .frame(maxHeight: 280)
  }

  private var selectedModelLabel: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(selectedModel?.displayName ?? "Codex default")
          .font(.body)
          .foregroundStyle(.primary)
          .lineLimit(1)

        if let description = selectedModelDescription {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 8)

      Image(systemName: "chevron.up.chevron.down")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(width: 320, alignment: .leading)
    .frame(minHeight: 54, alignment: .leading)
    .contentShape(RoundedRectangle(cornerRadius: 7))
    .background {
      RoundedRectangle(cornerRadius: 7)
        .fill(modelSelectorBackground)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .stroke(Color(NSColor.separatorColor).opacity(0.7), lineWidth: 1)
    }
  }

  private var modelSelectorBackground: Color {
    if isShowingModelOptions || isHoveringModelSelector {
      return Color(NSColor.selectedContentBackgroundColor).opacity(0.12)
    }
    return Color(NSColor.controlBackgroundColor)
  }

  private func modelOptionRow(for model: CodexModelDescriptor) -> some View {
    HStack(alignment: .top, spacing: 8) {
      if model.slug == preferences.codexModel {
        Image(systemName: "checkmark")
          .font(.caption)
          .foregroundStyle(.tint)
          .frame(width: 14, height: 18)
      } else {
        Color.clear
          .frame(width: 14, height: 18)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(model.displayName)
          .font(.body)
          .foregroundStyle(.primary)

        if let description = description(for: model) {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 7)
    .contentShape(RoundedRectangle(cornerRadius: 6))
    .background {
      if model.slug == preferences.codexModel {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.accentColor.opacity(0.12))
      }
    }
  }

  private var modelOptions: [CodexModelDescriptor] {
    let selected = preferences.codexModel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selected.isEmpty else { return models }
    guard !models.contains(where: { $0.slug == selected }) else { return models }

    return [
      CodexModelDescriptor(slug: selected, displayName: selected)
    ] + models
  }

  private var selectedModel: CodexModelDescriptor? {
    modelOptions.first { $0.slug == preferences.codexModel }
  }

  private var selectedModelDescription: String? {
    if let selectedModel, let description = description(for: selectedModel) {
      return description
    }

    let selected = preferences.codexModel.trimmingCharacters(in: .whitespacesAndNewlines)
    return selected.isEmpty ? nil : "Using \(selected)"
  }

  private var selectedModelAccessibilityValue: String {
    if let description = selectedModelDescription {
      return "\(selectedModel?.displayName ?? preferences.codexModel), \(description)"
    }
    return selectedModel?.displayName ?? preferences.codexModel
  }

  private func description(for model: CodexModelDescriptor) -> String? {
    let description = model.description?.trimmingCharacters(in: .whitespacesAndNewlines)
    return description?.isEmpty == false ? description : nil
  }
}
