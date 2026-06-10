//
//  EaselMenuBarAssetTests.swift
//  EaselTests
//

import AppKit
import Foundation
import Testing

struct EaselMenuBarAssetTests {

  @Test
  func menuBarAssetUsesTemplatePNGRepresentations() throws {
    let assetURL = repoRoot
      .appendingPathComponent("Easel/Assets.xcassets/easelmenubar.imageset")
    let contentsURL = assetURL.appendingPathComponent("Contents.json")
    let contents = try JSONDecoder().decode(
      MenuBarAssetContents.self,
      from: Data(contentsOf: contentsURL)
    )

    #expect(contents.properties.templateRenderingIntent == "template")
    let expectedRepresentations = [
      MenuBarAssetRepresentation(filename: "easel-menu-bar-icon.png", scale: "1x", pixels: 18),
      MenuBarAssetRepresentation(filename: "easel-menu-bar-icon@2x.png", scale: "2x", pixels: 36),
      MenuBarAssetRepresentation(filename: "easel-menu-bar-icon@3x.png", scale: "3x", pixels: 54),
    ]
    #expect(contents.images.count == expectedRepresentations.count)

    for (image, expectedRepresentation) in zip(contents.images, expectedRepresentations) {
      #expect(image.idiom == "universal")
      #expect(image.scale == expectedRepresentation.scale)
      #expect(image.filename == expectedRepresentation.filename)
      let bitmap = try bitmapRepresentation(
        at: assetURL.appendingPathComponent(expectedRepresentation.filename)
      )
      let counts = alphaCounts(in: bitmap)

      #expect(bitmap.pixelsWide == expectedRepresentation.pixels)
      #expect(bitmap.pixelsHigh == expectedRepresentation.pixels)
      #expect(bitmap.hasAlpha)
      #expect(counts.opaque > 0)
      #expect(counts.transparent > 0)
    }
  }

  private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func bitmapRepresentation(at url: URL) throws -> NSBitmapImageRep {
    let data = try Data(contentsOf: url)
    return try #require(NSBitmapImageRep(data: data))
  }

  private func alphaCounts(in bitmap: NSBitmapImageRep) -> (opaque: Int, transparent: Int) {
    var opaque = 0
    var transparent = 0

    for x in 0..<bitmap.pixelsWide {
      for y in 0..<bitmap.pixelsHigh {
        let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
        if alpha > 0.8 {
          opaque += 1
        } else if alpha < 0.05 {
          transparent += 1
        }
      }
    }

    return (opaque, transparent)
  }
}

private struct MenuBarAssetContents: Decodable {
  let images: [MenuBarAssetImage]
  let properties: MenuBarAssetProperties
}

private struct MenuBarAssetImage: Decodable {
  let filename: String?
  let idiom: String
  let scale: String
}

private struct MenuBarAssetProperties: Decodable {
  let templateRenderingIntent: String

  private enum CodingKeys: String, CodingKey {
    case templateRenderingIntent = "template-rendering-intent"
  }
}

private struct MenuBarAssetRepresentation {
  let filename: String
  let scale: String
  let pixels: Int
}
