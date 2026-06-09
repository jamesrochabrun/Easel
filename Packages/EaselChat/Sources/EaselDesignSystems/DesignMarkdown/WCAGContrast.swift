//
//  WCAGContrast.swift
//  EaselDesignSystems
//

import Foundation

/// WCAG 2.x relative-luminance and contrast-ratio math for hex colors.
public enum WCAGContrast {
  /// The minimum contrast ratio for normal body text at WCAG AA.
  public static let aaNormalText = 4.5

  /// Contrast ratio between two colors, or `nil` if either is not a parseable
  /// hex color (e.g. `oklch(...)` or a named color we don't evaluate).
  public static func contrastRatio(_ first: String, _ second: String) -> Double? {
    guard let l1 = relativeLuminance(hex: first),
          let l2 = relativeLuminance(hex: second) else {
      return nil
    }
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
  }

  /// Relative luminance (0…1) of a hex color, ignoring any alpha channel.
  public static func relativeLuminance(hex: String) -> Double? {
    guard let rgb = rgbComponents(hex: hex) else { return nil }
    func channel(_ value: Double) -> Double {
      value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
  }

  /// Parses `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` into sRGB components (0…1).
  static func rgbComponents(hex: String) -> (r: Double, g: Double, b: Double)? {
    var value = hex.trimmingCharacters(in: .whitespaces)
    guard value.hasPrefix("#") else { return nil }
    value.removeFirst()
    let scalars = value.unicodeScalars
    guard scalars.allSatisfy({ isHexDigit($0) }) else { return nil }

    let chars = Array(value)
    func component(_ pair: String) -> Double? {
      guard let intValue = UInt8(pair, radix: 16) else { return nil }
      return Double(intValue) / 255.0
    }

    switch chars.count {
    case 3, 4: // #RGB / #RGBA — expand each nibble
      guard let r = component(String([chars[0], chars[0]])),
            let g = component(String([chars[1], chars[1]])),
            let b = component(String([chars[2], chars[2]])) else { return nil }
      return (r, g, b)
    case 6, 8: // #RRGGBB / #RRGGBBAA
      guard let r = component(String(chars[0...1])),
            let g = component(String(chars[2...3])),
            let b = component(String(chars[4...5])) else { return nil }
      return (r, g, b)
    default:
      return nil
    }
  }

  private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
    (scalar >= "0" && scalar <= "9")
      || (scalar >= "a" && scalar <= "f")
      || (scalar >= "A" && scalar <= "F")
  }
}
