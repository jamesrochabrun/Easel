import SwiftUI
import AppKit

enum EaselChatRuntimeStyle {
  static let maxContentWidth: CGFloat = 420
  static let cardRadius: CGFloat = 8
  static let compactRadius: CGFloat = 6

  // MARK: - Typography

  enum Typography {
    static let primaryTitle: Font = .callout.bold()
    static let secondaryBody: Font = .caption
    static let tertiaryCaption: Font = .caption2
    static let assistantLabel: Font = .caption.bold()
    static let statusIcon: Font = .system(size: 10, weight: .semibold)
    static let toolIcon: Font = .system(size: 13)

    static func code(size: CGFloat) -> Font {
      .system(size: size, design: .monospaced)
    }

    static func codeBold(size: CGFloat) -> Font {
      .system(size: size, weight: .semibold, design: .monospaced)
    }
  }

  // MARK: - Spacing

  enum Spacing {
    static let cardPadding: CGFloat = 10
    static let cardPaddingCompact: CGFloat = 8
    static let previewPadding: CGFloat = 10
    static let cardContentSpacing: CGFloat = 6
    static let messageListSpacing: CGFloat = 6
    static let messageRowVertical: CGFloat = 1
    static let taskHeaderHorizontal: CGFloat = 10
    static let taskHeaderVertical: CGFloat = 8
    static let headerDotSpacing: CGFloat = 8
    static let statusDotSize: CGFloat = 8
    static let chevronSize: CGFloat = 10
  }

  static func appBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    Color.clear
  }

  static func panelBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    switch colorScheme {
    case .dark:
      return Color(nsColor: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 0.86))
    default:
      return Color(nsColor: NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 0.92))
    }
  }

  static func cardBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    switch colorScheme {
    case .dark:
      return Color(nsColor: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.16, alpha: 0.82))
    default:
      return Color(nsColor: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 0.94))
    }
  }

  static func subtleCardBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    switch colorScheme {
    case .dark:
      return Color(nsColor: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.11, alpha: 0.68))
    default:
      return Color(nsColor: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.98, alpha: 0.86))
    }
  }

  static func border(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    switch colorScheme {
    case .dark:
      return Color.white.opacity(0.16)
    default:
      return Color.black.opacity(0.10)
    }
  }

  static func secondaryText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.46)
  }

  static func tertiaryText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.28)
  }

  static func userBubble(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    switch colorScheme {
    case .dark:
      return Color(nsColor: NSColor(srgbRed: 0.86, green: 0.86, blue: 0.86, alpha: 1))
    default:
      return Color(nsColor: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1))
    }
  }

  static func userText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    readableForeground(for: userBubble(for: colorScheme, themeColors: themeColors))
  }

  static let completed = Color(red: 52, green: 211, blue: 128)
  static let running = Color(red: 102, green: 166, blue: 255)
  static let failed = Color(red: 242, green: 77, blue: 77)
  static let denied = Color(red: 255, green: 158, blue: 64)

  static func successBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? Color(red: 0.08, green: 0.20, blue: 0.11) : Color(red: 0.91, green: 0.98, blue: 0.93)
  }

  static func successForeground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? Color(red: 0.70, green: 0.96, blue: 0.74) : Color(red: 0.20, green: 0.58, blue: 0.27)
  }

  private static func readableForeground(for background: Color) -> Color {
    let resolvedBackground = NSColor(background).usingColorSpace(.sRGB) ?? .controlAccentColor
    let luminance = (
      (0.299 * resolvedBackground.redComponent) +
      (0.587 * resolvedBackground.greenComponent) +
      (0.114 * resolvedBackground.blueComponent)
    )
    return luminance > 0.62 ? Color.black.opacity(0.9) : .white
  }
}
