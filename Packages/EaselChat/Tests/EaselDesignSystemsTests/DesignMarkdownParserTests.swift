//
//  DesignMarkdownParserTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownParserTests {

  @Test
  func parsesFrontMatterTokens() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)

    #expect(document.version == "alpha")
    #expect(document.name == "Heritage")
    #expect(document.detail == "A premium editorial system.")

    #expect(document.colors.map(\.name) == ["primary", "secondary", "tertiary", "neutral"])
    #expect(document.colors.first?.value == "#1A1C1E")

    #expect(document.typography.map(\.name) == ["display-lg", "body-md", "label-caps"])
    let displayLarge = try #require(document.typography.first)
    #expect(displayLarge.fontFamily == "Public Sans")
    #expect(displayLarge.fontSize == "3rem")
    #expect(displayLarge.fontWeight == "700")

    #expect(document.rounded.map(\.name) == ["sm", "md"])
    #expect(document.rounded.first?.value == "4px")
    #expect(document.spacing.first(where: { $0.name == "md" })?.value == "16px")
  }

  @Test
  func parsesComponentTokenReferences() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)

    #expect(document.components.map(\.name) == ["button-primary", "button-primary-hover"])
    let button = try #require(document.components.first)
    #expect(button.properties.map(\.key) == ["backgroundColor", "textColor", "rounded", "padding"])

    let background = try #require(button.properties.first)
    guard case .reference(let reference) = background.value else {
      Issue.record("expected a token reference")
      return
    }
    #expect(reference.path == ["colors", "tertiary"])

    let padding = try #require(button.properties.first(where: { $0.key == "padding" }))
    #expect(padding.value == .literal("12px"))
  }

  @Test
  func parsesSectionsWithAliasAndOrder() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    #expect(document.sections.map(\.kind) == [.overview, .colors, .typography])
    #expect(document.sections.first?.body.contains("Architectural Minimalism") == true)
  }

  @Test
  func resolvesSectionAliases() {
    #expect(DesignSectionKind.match(heading: "Brand & Style") == .overview)
    #expect(DesignSectionKind.match(heading: "1. Visual Theme & Atmosphere") == .overview)
    #expect(DesignSectionKind.match(heading: "2. Color Palette & Roles") == .colors)
    #expect(DesignSectionKind.match(heading: "3. Typography Rules") == .typography)
    #expect(DesignSectionKind.match(heading: "4. Component Stylings") == .components)
    #expect(DesignSectionKind.match(heading: "Layout & Spacing") == .layout)
    #expect(DesignSectionKind.match(heading: "Elevation") == .elevation)
    #expect(DesignSectionKind.match(heading: "Do\u{2019}s and Don\u{2019}ts") == .dosAndDonts)
    #expect(DesignSectionKind.match(heading: "Responsive Behavior") == nil)
    #expect(DesignSectionKind.match(heading: "Mystery") == nil)
  }

  @Test
  func throwsWhenFrontMatterMissing() {
    #expect(throws: DesignMarkdownParseError.missingFrontMatter) {
      _ = try DesignMarkdownParser.parse("# Just markdown\n\nNo front matter here.")
    }
  }

  @Test
  func capturesUnknownFrontMatterKeys() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    #expect(document.unknownFrontMatterKeys.contains("brandTone"))
  }

  @Test
  func ignoresCommentsAndBlankLines() throws {
    let source = [
      "---",
      "name: Commented # trailing comment",
      "# full line comment",
      "colors:",
      "  primary: \"#000000\"  # inline",
      "---",
      "",
      "## Overview",
      "Body.",
    ].joined(separator: "\n")

    let document = try DesignMarkdownParser.parse(source)
    #expect(document.name == "Commented")
    #expect(document.colors.first?.value == "#000000")
  }
}
