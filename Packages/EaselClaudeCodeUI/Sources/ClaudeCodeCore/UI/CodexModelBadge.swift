//
//  CodexModelBadge.swift
//  ClaudeCodeUI
//

import SwiftUI

struct CodexModelBadge: View {
  let modelIdentifier: String

  var body: some View {
    ProviderModelBadge(
      providerName: "Codex",
      defaultDisplayText: "Codex default",
      modelIdentifier: modelIdentifier
    )
  }
}

struct ClaudeModelBadge: View {
  let modelIdentifier: String

  var body: some View {
    ProviderModelBadge(
      providerName: "Claude",
      defaultDisplayText: "Claude default",
      modelIdentifier: modelIdentifier
    )
  }
}

private struct ProviderModelBadge: View {
  let providerName: String
  let defaultDisplayText: String
  let modelIdentifier: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "cpu")
        .font(.system(size: 9, weight: .medium))

      Text(displayText)
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
    .padding(.horizontal, 7)
    .padding(.vertical, 3)
    .frame(maxWidth: 160)
    .background(EaselChatRuntimeStyle.panelBackground(for: colorScheme), in: Capsule())
    .overlay {
      Capsule()
        .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
    }
    .help("\(providerName) model: \(displayText)")
  }

  private var displayText: String {
    let trimmed = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? defaultDisplayText : trimmed
  }
}
