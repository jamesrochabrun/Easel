//
//  EaselDesignSystemTests.swift
//  EaselKitTests
//

import Testing
@testable import EaselKit

struct EaselDesignSystemTests {

  @Test
  func codexPaletteUsesExpectedCoreHexValues() {
    #expect(EaselDesignSystem.Palette.inkHex == "#0F1110")
    #expect(EaselDesignSystem.Palette.accentHex == "#10A37F")
    #expect(EaselDesignSystem.Palette.canvasLightHex == "#F7F7F4")
    #expect(EaselDesignSystem.Palette.canvasDarkHex == "#0D0F0E")
  }

  @Test
  func codexShapeTokensStayCompact() {
    #expect(EaselDesignSystem.Radius.control == 6)
    #expect(EaselDesignSystem.Radius.card == 8)
    #expect(EaselDesignSystem.Spacing.toolbarHeight == 40)
  }
}
