//
//  LocalAgentHandoffPathBadge.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffPathBadge: View {
  let path: String
  let isSelected: Bool

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "folder")
        .font(.caption.weight(.semibold))
        .foregroundStyle(
          isSelected
            ? EaselDesignSystem.Palette.accent
            : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
        )
        .accessibilityHidden(true)

      Text(path)
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineLimit(1)
        .truncationMode(.middle)
        .help(path)
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .accessibilityLabel(path)
  }
}
