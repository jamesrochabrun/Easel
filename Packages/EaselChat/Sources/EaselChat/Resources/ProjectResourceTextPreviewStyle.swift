//
//  ProjectResourceTextPreviewStyle.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct ProjectResourceTextPreviewStyle {
  let colorScheme: ColorScheme

  var editorBackground: Color {
    switch colorScheme {
    case .dark:
      Color(.sRGB, red: 0.07, green: 0.09, blue: 0.11, opacity: 1)
    case .light:
      EaselDesignSystem.Palette.surface(for: colorScheme)
    @unknown default:
      EaselDesignSystem.Palette.surface(for: .light)
    }
  }

  var headerBackground: Color {
    switch colorScheme {
    case .dark:
      Color(.sRGB, red: 0.09, green: 0.11, blue: 0.13, opacity: 1)
    case .light:
      EaselDesignSystem.Palette.surfaceElevated(for: colorScheme)
    @unknown default:
      EaselDesignSystem.Palette.surfaceElevated(for: .light)
    }
  }

  var headerSecondaryText: Color {
    EaselDesignSystem.Palette.secondaryText(for: colorScheme)
  }

  var headerBorder: Color {
    switch colorScheme {
    case .dark:
      Color.white.opacity(0.08)
    case .light:
      EaselDesignSystem.Palette.border(for: colorScheme)
    @unknown default:
      EaselDesignSystem.Palette.border(for: .light)
    }
  }

  var badgeBackground: Color {
    headerSecondaryText.opacity(colorScheme == .dark ? 0.14 : 0.11)
  }
}
