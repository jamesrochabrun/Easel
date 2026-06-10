//
//  DesignKindSymbolPalette.swift
//  EaselChat
//

import SwiftUI

enum DesignKindSymbolPalette {
  case prototype
  case slideDeck
  case designSystem

  func accent(for colorScheme: ColorScheme) -> Color {
    switch (self, colorScheme) {
    case (.prototype, .light):
      return Color(red: 0.22, green: 0.52, blue: 0.58)
    case (.prototype, .dark):
      return Color(red: 0.52, green: 0.82, blue: 0.82)
    case (.slideDeck, .light):
      return Color(red: 0.34, green: 0.45, blue: 0.74)
    case (.slideDeck, .dark):
      return Color(red: 0.66, green: 0.75, blue: 0.98)
    case (.designSystem, .light):
      return Color(red: 0.55, green: 0.42, blue: 0.68)
    case (.designSystem, .dark):
      return Color(red: 0.78, green: 0.68, blue: 0.92)
    @unknown default:
      return Color(red: 0.22, green: 0.52, blue: 0.58)
    }
  }

  func secondary(for colorScheme: ColorScheme) -> Color {
    switch (self, colorScheme) {
    case (.prototype, .light):
      return Color(red: 0.58, green: 0.78, blue: 0.74)
    case (.prototype, .dark):
      return Color(red: 0.22, green: 0.43, blue: 0.44)
    case (.slideDeck, .light):
      return Color(red: 0.64, green: 0.72, blue: 0.94)
    case (.slideDeck, .dark):
      return Color(red: 0.27, green: 0.34, blue: 0.54)
    case (.designSystem, .light):
      return Color(red: 0.76, green: 0.64, blue: 0.82)
    case (.designSystem, .dark):
      return Color(red: 0.38, green: 0.30, blue: 0.48)
    @unknown default:
      return Color(red: 0.58, green: 0.78, blue: 0.74)
    }
  }
}

extension DesignLibraryItemKind {
  var symbolPalette: DesignKindSymbolPalette {
    switch self {
    case .prototype:
      return .prototype
    case .slideDeck:
      return .slideDeck
    case .designSystem:
      return .designSystem
    }
  }
}
