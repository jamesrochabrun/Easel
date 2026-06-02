import XCTest
import SwiftUI
import AppKit
import EaselKit
@testable import ClaudeCodeCore

final class AppearanceSettingsTests: XCTestCase {

  func testCustomThemeColorsUseProvidedHexValues() {
    let colors = ThemeColors.themeColors(
      for: .custom,
      customPrimaryHex: "#112233",
      customSecondaryHex: "#445566",
      customTertiaryHex: "#778899"
    )

    XCTAssertEqual(hexString(for: colors.brandPrimary), "#112233")
    XCTAssertEqual(hexString(for: colors.brandSecondary), "#445566")
    XCTAssertEqual(hexString(for: colors.brandTertiary), "#778899")
  }

  func testRuntimeStyleSurfacesStayNeutralAcrossThemes() {
    let claude = ThemeColors.themeColors(for: .claude)
    let bat = ThemeColors.themeColors(for: .bat)

    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.appBackground(for: .light, themeColors: claude)),
      hexString(for: EaselChatRuntimeStyle.appBackground(for: .light, themeColors: bat))
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.cardBackground(for: .dark, themeColors: claude)),
      hexString(for: EaselChatRuntimeStyle.cardBackground(for: .dark, themeColors: bat))
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.userBubble(for: .dark, themeColors: claude)),
      hexString(for: EaselChatRuntimeStyle.userBubble(for: .dark, themeColors: bat))
    )
  }

  func testClearThemeUsesNeutralPalette() {
    let clear = ThemeColors.themeColors(for: .clear)

    XCTAssertEqual(hexString(for: clear.brandPrimary), "#1F2937")
    XCTAssertEqual(hexString(for: clear.brandSecondary), "#6B7280")
    XCTAssertEqual(hexString(for: clear.brandTertiary), "#D1D5DB")
  }

  func testCodexThemeUsesOpenAINeutralPalette() {
    let codex = ThemeColors.themeColors(for: .codex)

    XCTAssertEqual(hexString(for: codex.brandPrimary), EaselDesignSystem.Palette.inkHex)
    XCTAssertEqual(hexString(for: codex.brandSecondary), EaselDesignSystem.Palette.accentHex)
    XCTAssertEqual(hexString(for: codex.brandTertiary), EaselDesignSystem.Palette.borderLightHex)
  }

  func testRuntimeStyleUsesCodexSurfaces() {
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.appBackground(for: .light)),
      EaselDesignSystem.Palette.canvasLightHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.appBackground(for: .dark)),
      EaselDesignSystem.Palette.canvasDarkHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.userBubble(for: .light)),
      EaselDesignSystem.Palette.accentHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.userMessageBubble(for: .light)),
      EaselDesignSystem.Palette.surfaceElevatedLightHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.userMessageBubble(for: .dark)),
      EaselDesignSystem.Palette.borderDarkHex
    )
  }

  func testToolCardsUseGraphiteChromeAndCompletion() {
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.toolCardBorder(for: .dark)),
      EaselChatRuntimeStyle.toolCardBorderDarkHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.completed),
      EaselDesignSystem.Palette.accentHex
    )
    XCTAssertEqual(
      hexString(for: EaselChatRuntimeStyle.completedForeground(for: .dark)),
      EaselDesignSystem.Palette.accentForegroundDarkHex
    )
  }

  private func hexString(for color: Color) -> String {
    let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return Color.hexString(from: resolvedColor)
  }
}
