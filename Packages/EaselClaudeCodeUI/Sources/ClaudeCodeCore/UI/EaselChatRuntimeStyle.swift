import SwiftUI
import AppKit
import EaselKit

enum EaselChatRuntimeStyle {
  static let maxContentWidth: CGFloat = 432
  static let cardRadius: CGFloat = EaselDesignSystem.Radius.card
  static let compactRadius: CGFloat = EaselDesignSystem.Radius.control
  static let toolCardBorderDarkHex = EaselDesignSystem.Palette.accentHex

  // MARK: - Typography

  enum Typography {
    static let primaryTitle: Font = EaselDesignSystem.Typography.interface(size: 13, weight: .semibold)
    static let secondaryBody: Font = EaselDesignSystem.Typography.interface(size: 12)
    static let tertiaryCaption: Font = EaselDesignSystem.Typography.interface(size: 11)
    static let assistantLabel: Font = EaselDesignSystem.Typography.interface(size: 12, weight: .semibold)
    static let statusIcon: Font = EaselDesignSystem.Typography.interface(size: 10, weight: .semibold)
    static let toolIcon: Font = EaselDesignSystem.Typography.interface(size: 13)

    static func code(size: CGFloat) -> Font {
      EaselDesignSystem.Typography.code(size: size)
    }

    static func codeBold(size: CGFloat) -> Font {
      EaselDesignSystem.Typography.code(size: size, weight: .semibold)
    }
  }

  // MARK: - Spacing

  enum Spacing {
    static let cardPadding: CGFloat = EaselDesignSystem.Spacing.large
    static let cardPaddingCompact: CGFloat = EaselDesignSystem.Spacing.medium
    static let previewPadding: CGFloat = EaselDesignSystem.Spacing.large
    static let cardContentSpacing: CGFloat = EaselDesignSystem.Spacing.small
    static let messageListSpacing: CGFloat = EaselDesignSystem.Spacing.medium
    static let messageRowVertical: CGFloat = 1
    static let taskHeaderHorizontal: CGFloat = EaselDesignSystem.Spacing.large
    static let taskHeaderVertical: CGFloat = EaselDesignSystem.Spacing.medium
    static let headerDotSpacing: CGFloat = EaselDesignSystem.Spacing.medium
    static let statusDotSize: CGFloat = 8
    static let chevronSize: CGFloat = 10
  }

  static func appBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.canvas(for: colorScheme)
  }

  static func panelBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.surface(for: colorScheme)
  }

  static func cardBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.surface(for: colorScheme)
  }

  static func subtleCardBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  static func border(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.border(for: colorScheme)
  }

  static func toolCardBorder(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? Color(hex: toolCardBorderDarkHex) : border(for: colorScheme, themeColors: themeColors)
  }

  static func secondaryText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.secondaryText(for: colorScheme)
  }

  static func tertiaryText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }

  static func inputTint(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.selectionAccent(for: colorScheme)
  }

  static func userBubble(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.primaryAction(for: colorScheme)
  }

  static func userMessageBubble(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark
      ? EaselDesignSystem.Palette.border(for: colorScheme)
      : EaselDesignSystem.Palette.surfaceElevated(for: colorScheme)
  }

  static func userText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    readableForeground(for: userBubble(for: colorScheme, themeColors: themeColors))
  }

  static func userMessageText(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    readableForeground(for: userMessageBubble(for: colorScheme, themeColors: themeColors))
  }

  static let completed = EaselDesignSystem.Palette.accent
  static let running = EaselDesignSystem.Palette.running
  static let failed = EaselDesignSystem.Palette.danger
  static let denied = EaselDesignSystem.Palette.warning

  static func completedForeground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    EaselDesignSystem.Palette.accentForeground(for: colorScheme)
  }

  static func successBackground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? EaselDesignSystem.Palette.accent.opacity(0.16) : EaselDesignSystem.Palette.accent.opacity(0.10)
  }

  static func successForeground(for colorScheme: ColorScheme, themeColors: ThemeColors = .current) -> Color {
    colorScheme == .dark ? completedForeground(for: colorScheme, themeColors: themeColors) : EaselDesignSystem.Palette.accentMuted
  }

  private static func readableForeground(for background: Color) -> Color {
    let resolvedBackground = NSColor(background).usingColorSpace(.sRGB)
      ?? NSColor(EaselDesignSystem.Palette.accent)
    let luminance = (
      (0.299 * resolvedBackground.redComponent) +
      (0.587 * resolvedBackground.greenComponent) +
      (0.114 * resolvedBackground.blueComponent)
    )
    return luminance > 0.62 ? Color.black.opacity(0.9) : .white
  }
}
