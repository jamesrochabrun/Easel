//
//  DesignSystemSelectedChoiceRow.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

struct DesignSystemSelectedChoiceRow: View {
  let choice: EaselDesignSystemChoice
  let isFocused: Bool
  let isHighestPrecedence: Bool
  let onSelect: () -> Void
  let onRemove: () -> Void
  let onMakeHighestPrecedence: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "line.3.horizontal")
        .font(.callout.weight(.semibold))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(choice.displayName)
            .font(.callout.weight(.semibold))
            .lineLimit(1)

          if choice.preset != nil && choice.preset != EaselDesignSystemPreset.none {
            Text("Default")
              .font(.caption.weight(.medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(
                EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
                in: Capsule()
              )
          }
        }

        Text(isHighestPrecedence ? "Highest precedence" : choice.detail)
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)
      }

      Spacer()

      Button("Make highest", systemImage: "arrow.up.to.line", action: onMakeHighestPrecedence)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Make highest precedence")
        .disabled(isHighestPrecedence)

      Button("Remove", systemImage: "xmark", action: onRemove)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Remove")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isFocused ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear)
    .contentShape(Rectangle())
    .onTapGesture(perform: onSelect)
  }
}
