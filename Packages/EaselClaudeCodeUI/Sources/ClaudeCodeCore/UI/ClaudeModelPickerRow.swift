//
//  ClaudeModelPickerRow.swift
//  ClaudeCodeUI
//

import SwiftUI

struct ClaudeModelPickerRow: View {
  @Bindable var preferences: GlobalPreferencesStorage

  let models: [ClaudeModelDescriptor]
  let onRefresh: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Model")
        .font(.caption)
        .foregroundColor(.secondary)

      HStack(spacing: 8) {
        Menu {
          Button {
            select("")
          } label: {
            menuLabel(name: "Default", isSelected: preferences.claudeModel.isEmpty)
          }

          if !modelOptions.isEmpty {
            Divider()
            ForEach(modelOptions) { model in
              Button {
                select(model.identifier)
              } label: {
                menuLabel(
                  name: model.displayName,
                  isSelected: model.identifier == preferences.claudeModel
                )
              }
            }
          }
        } label: {
          menuButtonLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: 320, alignment: .leading)
        .accessibilityLabel("Claude Model")
        .accessibilityValue(selectedModelAccessibilityValue)

        Button(action: onRefresh) {
          Image(systemName: "arrow.clockwise")
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.bordered)
        .help("Refresh Claude model list")
      }

      TextField("CLI default (e.g. opus, sonnet)", text: $preferences.claudeModel)
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
        .frame(maxWidth: 320, alignment: .leading)

      Text(footnote)
        .font(.caption)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420, alignment: .leading)
    }
  }

  private func select(_ identifier: String) {
    guard preferences.claudeModel != identifier else { return }
    preferences.claudeModel = identifier
  }

  private var modelOptions: [ClaudeModelDescriptor] {
    let selected = preferences.claudeModel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selected.isEmpty else { return models }
    guard !models.contains(where: { $0.identifier == selected }) else { return models }

    return [
      ClaudeModelDescriptor(identifier: selected, displayName: selected, detail: "Custom model identifier")
    ] + models
  }

  private var selectedModel: ClaudeModelDescriptor? {
    modelOptions.first { $0.identifier == preferences.claudeModel }
  }

  private var footnote: String {
    if let detail = selectedModel?.detail, !detail.isEmpty {
      return detail
    }
    return "Pick a detected model, or type any exact identifier."
  }

  private var selectedModelAccessibilityValue: String {
    if preferences.claudeModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "Default"
    }
    return selectedModel?.displayName ?? preferences.claudeModel
  }

  private var menuButtonLabel: some View {
    HStack(spacing: 6) {
      Text(selectedModelDisplayName)
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer(minLength: 4)

      Image(systemName: "chevron.up.chevron.down")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 7)
        .fill(Color(NSColor.controlBackgroundColor))
    }
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .stroke(Color(NSColor.separatorColor).opacity(0.7), lineWidth: 1)
    }
    .contentShape(Rectangle())
  }

  private var selectedModelDisplayName: String {
    preferences.claudeModel.isEmpty ? "Default" : (selectedModel?.displayName ?? preferences.claudeModel)
  }

  @ViewBuilder
  private func menuLabel(name: String, isSelected: Bool) -> some View {
    if isSelected {
      Label(name, systemImage: "checkmark")
    } else {
      Text(name)
    }
  }
}
