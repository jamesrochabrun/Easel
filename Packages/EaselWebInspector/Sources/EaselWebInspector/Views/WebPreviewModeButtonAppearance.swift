//
//  WebPreviewModeButtonAppearance.swift
//  EaselWebInspector
//

import EaselKit
import SwiftUI

struct WebPreviewModeButtonAppearance {
  let isActive: Bool
  let accessibilityValue: String

  static func resolve(isActive: Bool) -> WebPreviewModeButtonAppearance {
    WebPreviewModeButtonAppearance(
      isActive: isActive,
      accessibilityValue: isActive ? "On" : "Off"
    )
  }

  func iconColor(for colorScheme: ColorScheme) -> Color {
    guard isActive else {
      return EaselDesignSystem.Palette.secondaryText(for: colorScheme)
    }

    if colorScheme == .dark {
      return color(214, 232, 228)
    }

    return .white
  }

  func backgroundColor(for colorScheme: ColorScheme) -> Color {
    guard isActive else { return .clear }
    return colorScheme == .dark ? color(22, 56, 66) : color(9, 96, 108)
  }

  func borderColor(for colorScheme: ColorScheme) -> Color {
    guard isActive else { return .clear }
    return colorScheme == .dark ? color(44, 112, 130) : color(7, 74, 82)
  }

  private func color(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
  }
}
