//
//  Color+Inspector.swift
//  EaselWebInspector
//
//  Design tokens for the web inspector views.
//

import AppKit
import SwiftUI

extension Color {
  static var surfaceElevated: Color {
    Color(NSColor.controlBackgroundColor)
  }

  static var surfaceCanvas: Color {
    Color(NSColor.windowBackgroundColor)
  }

  static var brandPrimary: Color {
    .accentColor
  }

  static func hexString(from color: NSColor) -> String {
    let resolved = color.usingColorSpace(.sRGB) ?? color
    let r = Int(round(resolved.redComponent * 255))
    let g = Int(round(resolved.greenComponent * 255))
    let b = Int(round(resolved.blueComponent * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}

extension View {
  func webPreviewPrimaryButtonStyle() -> some View {
    buttonStyle(.borderedProminent)
      .tint(.brandPrimary)
  }

  func webPreviewSecondaryButtonStyle() -> some View {
    buttonStyle(.bordered)
      .tint(.brandPrimary)
  }
}
