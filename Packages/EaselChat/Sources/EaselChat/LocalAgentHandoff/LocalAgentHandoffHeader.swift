//
//  LocalAgentHandoffHeader.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffHeader: View {
  let onClose: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "square.and.arrow.up")
        .font(.title3.weight(.semibold))
        .foregroundStyle(EaselDesignSystem.Palette.accent)

      Text("Share Handoff")
        .font(.title2.weight(.semibold))

      Spacer()

      Button("Close", systemImage: "xmark", action: onClose)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Close")
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
  }
}
