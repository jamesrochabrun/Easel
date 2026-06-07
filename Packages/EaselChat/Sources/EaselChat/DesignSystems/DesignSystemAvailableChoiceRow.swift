//
//  DesignSystemAvailableChoiceRow.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

struct DesignSystemAvailableChoiceRow: View {
  let choice: EaselDesignSystemChoice
  let onAdd: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onAdd) {
      HStack(spacing: 12) {
        Image(systemName: choice.kind == .custom ? "square.grid.2x2" : "text.badge.checkmark")
          .font(.callout.weight(.medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        VStack(alignment: .leading, spacing: 4) {
          Text(choice.displayName)
            .font(.callout.weight(.semibold))
            .lineLimit(1)

          Text(choice.detail)
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: "plus")
          .font(.caption.weight(.bold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
