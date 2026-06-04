//
//  AccentColorAssetTests.swift
//  EaselTests
//

import EaselKit
import Foundation
import Testing

struct AccentColorAssetTests {

  @Test
  func globalAccentAssetsMatchDesignSystemAccent() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let assetPaths = [
      "Easel/Assets.xcassets/AccentColor.colorset/Contents.json",
      "Packages/EaselClaudeCodeUI/Sources/ClaudeCodeCore/Assets.xcassets/AccentColor.colorset/Contents.json",
    ]

    for assetPath in assetPaths {
      let assetURL = repoRoot.appendingPathComponent(assetPath)
      let asset = try JSONDecoder().decode(
        AccentColorAsset.self,
        from: Data(contentsOf: assetURL)
      )

      #expect(asset.firstHexColor == EaselDesignSystem.Palette.accentHex)
    }
  }
}

private struct AccentColorAsset: Decodable {
  let colors: [ColorEntry]

  var firstHexColor: String? {
    colors.first?.color.components.hexColor
  }
}

private struct ColorEntry: Decodable {
  let color: ColorValue
}

private struct ColorValue: Decodable {
  let components: ColorComponents
}

private struct ColorComponents: Decodable {
  let red: String
  let green: String
  let blue: String

  var hexColor: String? {
    guard let red = hexComponent(red),
      let green = hexComponent(green),
      let blue = hexComponent(blue)
    else {
      return nil
    }

    return String(format: "#%02X%02X%02X", red, green, blue)
  }

  private func hexComponent(_ value: String) -> Int? {
    if value.hasPrefix("0x") {
      return Int(value.dropFirst(2), radix: 16)
    }

    guard let decimalValue = Double(value) else {
      return nil
    }

    return Int(round(decimalValue * 255))
  }
}
