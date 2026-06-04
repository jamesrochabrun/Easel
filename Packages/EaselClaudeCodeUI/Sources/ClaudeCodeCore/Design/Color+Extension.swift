//  Color+Extension.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/8/25.

import SwiftUI
import AppKit
import EaselKit

/// Available app themes
public enum AppTheme: String, CaseIterable, Identifiable {
  case codex = "codex"
  case clear = "clear"
  case claude = "claude"
  case bat = "bat"
  case xcode = "Blue"
  case custom = "custom"
  
  public var id: String { rawValue }
  
  public var displayName: String {
    switch self {
    case .codex: return "Codex"
    case .clear: return "Clear"
    case .claude: return "Claude"
    case .bat: return "Bat"
    case .xcode: return "Blue"
    case .custom: return "Custom"
    }
  }
  
  public var description: String {
    switch self {
    case .codex: return "OpenAI-inspired neutrals with a focused neutral accent"
    case .clear: return "Clean neutral grays"
    case .claude: return "Warm earth tones"
    case .bat: return "Purple with mustard accents"
    case .xcode: return "Cool blues"
    case .custom: return "User-defined colors"
    }
  }
}

/// Theme color definitions
public struct ThemeColors {
  public let brandPrimary: Color
  public let brandSecondary: Color
  public let brandTertiary: Color
  
  public init(brandPrimary: Color, brandSecondary: Color, brandTertiary: Color) {
    self.brandPrimary = brandPrimary
    self.brandSecondary = brandSecondary
    self.brandTertiary = brandTertiary
  }

  static var current: ThemeColors {
    let selectedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.codex.rawValue
    let theme = AppTheme(rawValue: selectedTheme) ?? .codex
    return themeColors(
      for: theme,
      customPrimaryHex: UserDefaults.standard.string(forKey: "customPrimaryHex"),
      customSecondaryHex: UserDefaults.standard.string(forKey: "customSecondaryHex"),
      customTertiaryHex: UserDefaults.standard.string(forKey: "customTertiaryHex")
    )
  }

  static func themeColors(
    for theme: AppTheme,
    customPrimaryHex: String? = nil,
    customSecondaryHex: String? = nil,
    customTertiaryHex: String? = nil
  ) -> ThemeColors {
    switch theme {
    case .codex:
      return ThemeColors(
        brandPrimary: EaselDesignSystem.Palette.ink,
        brandSecondary: EaselDesignSystem.Palette.accent,
        brandTertiary: EaselDesignSystem.Palette.border(for: .light)
      )
    case .clear:
      return ThemeColors(
        brandPrimary: Color(hex: "#1F2937"),
        brandSecondary: Color(hex: "#6B7280"),
        brandTertiary: Color(hex: "#D1D5DB")
      )
    case .claude:
      return ThemeColors(
        brandPrimary: Color(hex: "#CC785C"),
        brandSecondary: Color(hex: "#D4A27F"),
        brandTertiary: Color(hex: "#EBDBBC")
      )
    case .bat:
      return ThemeColors(
        brandPrimary: Color(hex: "#7C3AED"),
        brandSecondary: Color(hex: "#FFB000"),
        brandTertiary: Color(hex: "#64748B")
      )
    case .xcode:
      return ThemeColors(
        brandPrimary: Color(nsColor: .systemBlue),
        brandSecondary: Color(nsColor: .systemIndigo),
        brandTertiary: Color(nsColor: .systemTeal)
      )
    case .custom:
      return ThemeColors(
        brandPrimary: Color(hex: customPrimaryHex ?? EaselDesignSystem.Palette.inkHex),
        brandSecondary: Color(hex: customSecondaryHex ?? EaselDesignSystem.Palette.accentHex),
        brandTertiary: Color(hex: customTertiaryHex ?? EaselDesignSystem.Palette.borderLightHex)
      )
    }
  }
}

extension Color {
  /// Create a Color from 0...255 RGB values (and optional alpha)
  init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
    self.init(.sRGB,
              red: red / 255.0,
              green: green / 255.0,
              blue: blue / 255.0,
              opacity: alpha)
  }
  
  init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
    self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: alpha)
  }
  
  /// Create a Color from a hex string like "#CC785C" or "CC785C"
  init(hex: String, alpha: Double = 1.0) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)
    
    let r, g, b: UInt64
    switch hex.count {
    case 6: // RGB (24-bit)
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (0, 0, 0)
    }
    
    self.init(red: Int(r), green: Int(g), blue: Int(b), alpha: alpha)
  }
  
  // MARK: - Named Colors (Legacy - use brand colors instead)
  
  static let bookCloth = EaselDesignSystem.Palette.ink
  static let kraft = EaselDesignSystem.Palette.accent
  static let manilla = EaselDesignSystem.Palette.border(for: .light)
  
  // MARK: - Theme-Aware Brand Colors

  static var brandPrimary: Color {
    ThemeColors.current.brandPrimary
  }

  static var brandSecondary: Color {
    ThemeColors.current.brandSecondary
  }

  static var brandTertiary: Color {
    ThemeColors.current.brandTertiary
  }
  static let backgroundDark = EaselDesignSystem.Palette.canvas(for: .dark)
  static let backgroundLight = EaselDesignSystem.Palette.canvas(for: .light)
  static let expandedContentBackgroundDark = EaselDesignSystem.Palette.surface(for: .dark)
  static let expandedContentBackgroundLight = EaselDesignSystem.Palette.surface(for: .light)
  
  // MARK: - Adaptive Colors
  
  static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? backgroundDark : backgroundLight
  }
  
  static func adaptiveExpandedContentBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? expandedContentBackgroundDark : expandedContentBackgroundLight
  }
  
}

// MARK: - Hex <-> NSColor Bridging
extension Color {
  /// Convert an NSColor to a hex string like #RRGGBB
  static func hexString(from nsColor: NSColor) -> String {
    let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
    let r = Int(round(color.redComponent * 255))
    let g = Int(round(color.greenComponent * 255))
    let b = Int(round(color.blueComponent * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}

extension NSColor {
  /// Create an NSColor from a hex string like #RRGGBB
  static func fromHex(_ hex: String) -> NSColor {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: cleaned).scanHexInt64(&int)
    let r, g, b: UInt64
    switch cleaned.count {
    case 6:
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (16, 163, 127)
    }
    return NSColor(srgbRed: CGFloat(r) / 255.0,
                   green: CGFloat(g) / 255.0,
                   blue: CGFloat(b) / 255.0,
                   alpha: 1.0)
  }
  
  /// Hex string like #RRGGBB
  func toHexString() -> String {
    Color.hexString(from: self)
  }
}
