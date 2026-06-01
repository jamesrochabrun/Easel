//
//  EaselDesignSystem.swift
//  EaselKit
//

import SwiftUI

public enum EaselDesignSystem {
  public enum Palette {
    public static let inkHex = "#0F1110"
    public static let accentHex = "#2E2F2F"
    public static let accentMutedHex = "#2E2F2F"
    public static let canvasLightHex = "#F7F7F4"
    public static let canvasDarkHex = "#0D0F0E"
    public static let surfaceLightHex = "#FFFFFF"
    public static let surfaceDarkHex = "#151716"
    public static let surfaceElevatedLightHex = "#EFEFED"
    public static let surfaceElevatedDarkHex = "#1B1E1C"
    public static let borderLightHex = "#D9DAD6"
    public static let borderDarkHex = "#2E332F"
    public static let textSecondaryLightHex = "#5F6761"
    public static let textSecondaryDarkHex = "#AEB7B0"
    public static let textTertiaryLightHex = "#8B928C"
    public static let textTertiaryDarkHex = "#747C76"
    public static let accentForegroundDarkHex = "#AEB7B0"

    public static let ink = color(15, 17, 16)
    public static let accent = color(46, 47, 47)
    public static let accentMuted = color(46, 47, 47)
    public static let warning = color(214, 142, 58)
    public static let danger = color(211, 75, 65)
    public static let running = color(82, 140, 255)
    public static let success = color(48, 200, 120)

    public static func canvas(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(13, 15, 14) : color(247, 247, 244)
    }

    public static func surface(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(21, 23, 22) : color(255, 255, 255)
    }

    public static func surfaceElevated(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(27, 30, 28) : color(239, 239, 237)
    }

    public static func subtleSurface(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(18, 21, 19) : color(251, 251, 249)
    }

    public static func selectedSurface(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? accent.opacity(0.18) : accent.opacity(0.12)
    }

    public static func hoverSurface(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? Color.white.opacity(0.06) : ink.opacity(0.05)
    }

    public static func border(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(46, 51, 47) : color(217, 218, 214)
    }

    public static func secondaryText(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(174, 183, 176) : color(95, 103, 97)
    }

    public static func tertiaryText(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(116, 124, 118) : color(139, 146, 140)
    }

    public static func primaryAction(for colorScheme: ColorScheme) -> Color {
      accent
    }

    public static func primaryActionForeground(for colorScheme: ColorScheme) -> Color {
      .white
    }

    public static func accentForeground(for colorScheme: ColorScheme) -> Color {
      colorScheme == .dark ? color(174, 183, 176) : accent
    }

    private static func color(_ red: Double, _ green: Double, _ blue: Double, alpha: Double = 1) -> Color {
      Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: alpha)
    }
  }

  public enum Radius {
    public static let control: CGFloat = 6
    public static let card: CGFloat = 8
    public static let panel: CGFloat = 10
    public static let preview: CGFloat = 12
  }

  public enum Spacing {
    public static let xSmall: CGFloat = 4
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 8
    public static let large: CGFloat = 12
    public static let xLarge: CGFloat = 16
    public static let panelPadding: CGFloat = 12
    public static let toolbarHeight: CGFloat = 40
  }

  public enum Typography {
    public static func interface(size: CGFloat, weight: Font.Weight = .regular) -> Font {
      .system(size: size, weight: weight)
    }

    public static func code(size: CGFloat, weight: Font.Weight = .regular) -> Font {
      .system(size: size, weight: weight, design: .monospaced)
    }
  }
}
