//
//  Color+Hex.swift
//  EaselChat
//

import SwiftUI

extension Color {
  /// Creates a color from a `#RGB`, `#RRGGBB`, or `#RRGGBBAA` hex string (with or
  /// without a leading `#`). Returns `nil` when the string isn't valid hex — used
  /// to render extracted Figma color tokens, whose values come from parsed data.
  init?(designSystemHex hex: String) {
    var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.hasPrefix("#") {
      cleaned.removeFirst()
    }
    guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }

    // Expand shorthand #RGB → #RRGGBB.
    if cleaned.count == 3 {
      cleaned = cleaned.map { "\($0)\($0)" }.joined()
    }
    guard cleaned.count == 6 || cleaned.count == 8 else { return nil }
    guard let value = UInt64(cleaned, radix: 16) else { return nil }

    let red, green, blue, alpha: Double
    if cleaned.count == 8 {
      red = Double((value >> 24) & 0xFF) / 255
      green = Double((value >> 16) & 0xFF) / 255
      blue = Double((value >> 8) & 0xFF) / 255
      alpha = Double(value & 0xFF) / 255
    } else {
      red = Double((value >> 16) & 0xFF) / 255
      green = Double((value >> 8) & 0xFF) / 255
      blue = Double(value & 0xFF) / 255
      alpha = 1
    }

    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}
