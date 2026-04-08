import SwiftUI

enum EaselChatRuntimeStyle {
  static let maxContentWidth: CGFloat = 420
  static let cardRadius: CGFloat = 8
  static let compactRadius: CGFloat = 6

  static func appBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.07) : .white
  }

  static func panelBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.10) : Color(red: 0.96, green: 0.96, blue: 0.96)
  }

  static func cardBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.14) : Color(red: 0.95, green: 0.95, blue: 0.95)
  }

  static func subtleCardBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.98, green: 0.98, blue: 0.98)
  }

  static func border(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
  }

  static func secondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.46)
  }

  static func tertiaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.28)
  }

  static func userBubble(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.09, green: 0.09, blue: 0.09)
  }

  static func userText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.black.opacity(0.92) : .white
  }

  static let completed = Color(red: 0.30, green: 0.77, blue: 0.38)
  static let running = Color(red: 0.36, green: 0.58, blue: 0.96)
  static let failed = Color(red: 0.92, green: 0.22, blue: 0.22)
  static let denied = Color(red: 0.95, green: 0.58, blue: 0.22)

  static func successBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.08, green: 0.20, blue: 0.11) : Color(red: 0.91, green: 0.98, blue: 0.93)
  }

  static func successForeground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.70, green: 0.96, blue: 0.74) : Color(red: 0.20, green: 0.58, blue: 0.27)
  }
}
