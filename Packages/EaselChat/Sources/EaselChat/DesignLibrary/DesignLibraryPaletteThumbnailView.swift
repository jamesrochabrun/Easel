//
//  DesignLibraryPaletteThumbnailView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

/// Renders a design system's color tokens as a palette filling the card's 16:9
/// thumbnail area — a band of equal-width swatches that reads as the system's
/// identity at a glance.
struct DesignLibraryPaletteThumbnailView: View {
  let colors: [EaselDesignSystemColorToken]

  @Environment(\.colorScheme) private var colorScheme

  /// Cap the number of stripes so each stays a legible width on a narrow card.
  private static let maxSwatches = 14

  private var swatches: [EaselDesignSystemColorToken] {
    Array(colors.prefix(Self.maxSwatches))
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(swatches) { token in
        swatchColor(for: token)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.surfaceElevated(for: colorScheme))
  }

  private func swatchColor(for token: EaselDesignSystemColorToken) -> Color {
    Color(designSystemHex: token.hex)
      ?? EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }
}
