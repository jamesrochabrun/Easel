//
//  DesignKindSymbolPaletteTests.swift
//  EaselTests
//

import AppKit
import SwiftUI
import Testing

@testable import EaselChat

struct DesignKindSymbolPaletteTests {
  @Test
  func symbolAccentColorsAreDistinctPerKindInBothAppearances() {
    let lightAccents = Set(DesignLibraryItemKind.allCases.map { hexString(of: $0.symbolPalette.accent(for: .light)) })
    let darkAccents = Set(DesignLibraryItemKind.allCases.map { hexString(of: $0.symbolPalette.accent(for: .dark)) })

    #expect(lightAccents.count == DesignLibraryItemKind.allCases.count)
    #expect(darkAccents.count == DesignLibraryItemKind.allCases.count)
  }

  @Test
  func symbolSecondaryColorsAreDistinctPerKindInBothAppearances() {
    let lightSecondaryColors = Set(DesignLibraryItemKind.allCases.map { hexString(of: $0.symbolPalette.secondary(for: .light)) })
    let darkSecondaryColors = Set(DesignLibraryItemKind.allCases.map { hexString(of: $0.symbolPalette.secondary(for: .dark)) })

    #expect(lightSecondaryColors.count == DesignLibraryItemKind.allCases.count)
    #expect(darkSecondaryColors.count == DesignLibraryItemKind.allCases.count)
  }

  @Test
  func projectKindsResolveToTheirMatchingLibraryPalettes() {
    #expect(DesignLibraryItemKind(projectKind: .prototype).symbolPalette == .prototype)
    #expect(DesignLibraryItemKind(projectKind: .slideDeck).symbolPalette == .slideDeck)
    #expect(DesignLibraryItemKind(projectKind: .animation).symbolPalette == .animation)
  }
}

private func hexString(of color: Color) -> String {
  components(of: color).hex
}

private func components(of color: Color) -> (hex: String, alpha: CGFloat) {
  let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
  let red = Int(round(resolvedColor.redComponent * 255))
  let green = Int(round(resolvedColor.greenComponent * 255))
  let blue = Int(round(resolvedColor.blueComponent * 255))
  return (
    String(format: "#%02X%02X%02X", red, green, blue),
    resolvedColor.alphaComponent
  )
}
