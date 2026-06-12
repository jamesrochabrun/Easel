//
//  DesignSystemPaletteGradient.swift
//  EaselChat
//

import AppKit
import EaselDesignSystems
import SwiftUI

/// Derives a small, vivid gradient from a design system's palette for the card's
/// "Design system" badge chip. Prefers saturated, mid-bright tokens (the brand
/// accents) and falls back to the first parseable colors when a palette is mostly
/// neutral.
enum DesignSystemPaletteGradient {
  static func accentColors(
    from tokens: [EaselDesignSystemColorToken],
    limit: Int = 4
  ) -> [Color] {
    let parsed: [(color: Color, saturation: CGFloat, brightness: CGFloat)] = tokens.compactMap { token in
      guard let color = Color(designSystemHex: token.hex),
            let rgb = NSColor(color).usingColorSpace(.deviceRGB) else {
        return nil
      }
      return (color, rgb.saturationComponent, rgb.brightnessComponent)
    }

    let vivid = parsed
      .filter { $0.saturation > 0.25 && $0.brightness > 0.3 }
      .map(\.color)

    if vivid.count >= 2 {
      return Array(vivid.prefix(limit))
    }

    return Array(parsed.map(\.color).prefix(limit))
  }
}
