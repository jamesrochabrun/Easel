//
//  Color+Inspector.swift
//  EaselWebInspector
//
//  Design tokens for the web inspector views.
//

import AppKit
import EaselKit
import SwiftUI

extension Color {
  static var surfaceElevated: Color {
    EaselDesignSystem.Palette.surfaceElevated(for: .light)
  }

  static var surfaceCanvas: Color {
    EaselDesignSystem.Palette.canvas(for: .light)
  }

  static var brandPrimary: Color {
    EaselDesignSystem.Palette.accent
  }

  static func hexString(from color: NSColor) -> String {
    let resolved = color.usingColorSpace(.sRGB) ?? color
    let r = Int(round(resolved.redComponent * 255))
    let g = Int(round(resolved.greenComponent * 255))
    let b = Int(round(resolved.blueComponent * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}

extension View {
  func webPreviewPrimaryButtonStyle() -> some View {
    modifier(WebPreviewButtonStyle(prominence: .primary))
  }

  func webPreviewSecondaryButtonStyle() -> some View {
    modifier(WebPreviewButtonStyle(prominence: .secondary))
  }
}

/// Applies the inspector's button styling with a color-scheme-aware tint.
///
/// The brand accent (`#2E2F2F`) is a near-black charcoal tuned for light mode.
/// On a `.bordered` button the tint colors the *label*, so using the raw accent
/// in dark mode renders the icon and text dark-on-dark — making the control look
/// disabled. `accentForeground(for:)` resolves to a legible light gray in dark
/// mode and the dark accent in light mode, keeping contrast in both appearances.
private struct WebPreviewButtonStyle: ViewModifier {
  enum Prominence {
    case primary
    case secondary
  }

  @Environment(\.colorScheme) private var colorScheme
  let prominence: Prominence

  @ViewBuilder
  func body(content: Content) -> some View {
    switch prominence {
    case .primary:
      // Filled button: the accent is the background, foreground stays white.
      content
        .buttonStyle(.borderedProminent)
        .tint(EaselDesignSystem.Palette.accent)
    case .secondary:
      // Bordered button: the tint is the label color, so it must adapt.
      content
        .buttonStyle(.bordered)
        .tint(EaselDesignSystem.Palette.accentForeground(for: colorScheme))
    }
  }
}
