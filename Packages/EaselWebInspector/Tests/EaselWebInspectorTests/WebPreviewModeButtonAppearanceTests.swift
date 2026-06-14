//
//  WebPreviewModeButtonAppearanceTests.swift
//  EaselWebInspectorTests
//

import AppKit
import EaselKit
import SwiftUI
import Testing
@testable import EaselWebInspector

private func hexString(of color: Color) -> String {
  let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
  let red = Int(round(resolvedColor.redComponent * 255))
  let green = Int(round(resolvedColor.greenComponent * 255))
  let blue = Int(round(resolvedColor.blueComponent * 255))
  return String(format: "#%02X%02X%02X", red, green, blue)
}

@Suite("WebPreviewModeButtonAppearance")
struct WebPreviewModeButtonAppearanceTests {
  @Test("Inactive mode keeps the neutral icon color")
  func inactiveModeKeepsNeutralIconColor() {
    let inactive = WebPreviewModeButtonAppearance.resolve(isActive: false)

    #expect(hexString(of: inactive.iconColor(for: .light)) == EaselDesignSystem.Palette.textSecondaryLightHex)
    #expect(hexString(of: inactive.iconColor(for: .dark)) == EaselDesignSystem.Palette.textSecondaryDarkHex)
  }

  @Test("Active mode uses a teal selected surface")
  func activeModeUsesTealSelectedSurface() {
    let active = WebPreviewModeButtonAppearance.resolve(isActive: true)

    #expect(hexString(of: active.backgroundColor(for: .dark)) == "#163842")
    #expect(hexString(of: active.borderColor(for: .dark)) == "#2C7082")
    #expect(hexString(of: active.iconColor(for: .dark)) == "#D6E8E4")
    #expect(hexString(of: active.backgroundColor(for: .light)) == "#09606C")
    #expect(hexString(of: active.borderColor(for: .light)) == "#074A52")
    #expect(hexString(of: active.iconColor(for: .light)) == "#FFFFFF")
  }

  @Test("Active mode exposes accessible state")
  func activeModeShowsAccessibilityValue() {
    let inactive = WebPreviewModeButtonAppearance.resolve(isActive: false)
    let active = WebPreviewModeButtonAppearance.resolve(isActive: true)

    #expect(inactive.accessibilityValue == "Off")
    #expect(active.accessibilityValue == "On")
  }
}
