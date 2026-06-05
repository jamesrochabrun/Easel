//
//  DesignLibraryBadgeTint.swift
//  EaselChat
//

import SwiftUI

enum DesignLibraryBadgeTint {
  case neutral
  case soft
  case warm

  func background(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .neutral:
      return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    case .soft:
      return colorScheme == .dark
        ? Color(red: 0.56, green: 0.42, blue: 0.44).opacity(0.30)
        : Color(red: 0.95, green: 0.88, blue: 0.88)
    case .warm:
      return colorScheme == .dark
        ? Color(red: 0.86, green: 0.44, blue: 0.32).opacity(0.24)
        : Color(red: 0.96, green: 0.91, blue: 0.84)
    }
  }
}
