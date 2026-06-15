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
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "paperplane.fill")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(width: 40, height: 40)
        .background(
          EaselDesignSystem.Palette.surfaceElevated(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        )
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Send Handoff")
          .font(.title2.weight(.semibold))

        Text("Hand this Easel project to a coding agent to implement.")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Button("Close", systemImage: "xmark", action: onClose)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.body.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Close")
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 22)
  }
}
