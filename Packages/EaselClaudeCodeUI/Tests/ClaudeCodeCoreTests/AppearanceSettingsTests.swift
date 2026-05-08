import XCTest
import SwiftUI
import AppKit
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

  private func hexString(for color: Color) -> String {
    let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return Color.hexString(from: resolvedColor)
  }
}
