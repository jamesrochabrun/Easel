//
//  DesignLibraryFilterChip.swift
//  EaselChat
//

import EaselKit
import SwiftUI

/// A toggleable pill used to filter the design library by item kind. Selected
/// chips read as "filled" with primary-contrast content; deselected chips are
/// dimmed with an outline so the off state is unmistakable in light and dark.
public struct DesignLibraryFilterChip: View {
  let kind: DesignLibraryItemKind
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovering = false

  public init(
    kind: DesignLibraryItemKind,
    count: Int,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.kind = kind
    self.count = count
    self.isSelected = isSelected
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: kind.systemImage)
          .font(.system(size: 11, weight: .semibold))

        Text(kind.pluralDisplayName)
          .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))

        if count > 0 {
          Text("\(count)")
            .font(EaselDesignSystem.Typography.interface(size: 11, weight: .semibold))
            .monospacedDigit()
            .opacity(0.7)
        }
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(background, in: Capsule())
      .overlay {
        Capsule()
          .stroke(borderColor, lineWidth: 1)
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .help(isSelected
          ? "Hide \(kind.pluralDisplayName.lowercased())"
          : "Show \(kind.pluralDisplayName.lowercased())")
    .accessibilityLabel(kind.pluralDisplayName)
    .accessibilityValue(isSelected ? "Shown" : "Hidden")
    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    .animation(.easeOut(duration: 0.12), value: isSelected)
  }

  private var foreground: Color {
    isSelected
      ? .primary
      : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }

  private var background: Color {
    if isSelected {
      return colorScheme == .dark
        ? Color.white.opacity(0.10)
        : Color.black.opacity(0.06)
    }
    return isHovering
      ? EaselDesignSystem.Palette.hoverSurface(for: colorScheme)
      : .clear
  }

  private var borderColor: Color {
    if isSelected {
      return colorScheme == .dark
        ? Color.white.opacity(0.16)
        : Color.black.opacity(0.12)
    }
    return EaselDesignSystem.Palette.border(for: colorScheme)
  }
}
