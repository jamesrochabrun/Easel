//
//  DesignMarkdownCatalogMapperTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownCatalogMapperTests {

  @Test
  func mapsRoundedToRadiiAndConvertsRem() throws {
    let document = try DesignMarkdownParser.parse([
      "---",
      "name: Mapped",
      "rounded:",
      "  sm: 4px",
      "spacing:",
      "  md: 1rem",
      "---",
      "## Overview",
      "Body.",
    ].joined(separator: "\n"))

    let tokens = DesignMarkdownCatalogMapper.makeTokenSet(from: document)
    #expect(tokens.radii.first?.name == "sm")
    #expect(tokens.radii.first?.value == 4)
    #expect(tokens.radii.first?.unit == "px")
    // 1rem → 16px
    #expect(tokens.spacing.first?.value == 16)
    #expect(tokens.spacing.first?.unit == "px")
  }

  @Test
  func normalizesColorsAndResolvesReferences() throws {
    let document = try DesignMarkdownParser.parse([
      "---",
      "name: Colors",
      "colors:",
      "  primary: \"1A1C1E\"", // bare hex (no leading #)
      "  brand: \"{colors.primary}\"", // reference
      "  accent: \"oklch(62% 0.18 250)\"", // non-hex CSS, kept verbatim
      "---",
      "## Overview",
      "Body.",
    ].joined(separator: "\n"))

    let tokens = DesignMarkdownCatalogMapper.makeTokenSet(from: document)
    let byName = Dictionary(uniqueKeysWithValues: tokens.colors.map { ($0.name, $0.hex) })
    #expect(byName["primary"] == "#1A1C1E")
    #expect(byName["brand"] == "#1A1C1E") // resolved through the reference
    #expect(byName["accent"] == "oklch(62% 0.18 250)")
  }

  @Test
  func surfacesComponentFamiliesGroupedByState() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    let catalog = DesignMarkdownCatalogMapper.makeCatalog(from: document, profile: profile())

    let families = try #require(catalog.componentFamilies)
    let button = try #require(families.first { $0.id == "button-primary" })
    #expect(button.variantCount == 2) // default + hover
    #expect(button.variantProperties.first?.values.contains("hover") == true)
  }

  @Test
  func synthesizesPreviewScenesForImportedComponents() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    let catalog = DesignMarkdownCatalogMapper.makeCatalog(from: document, profile: profile())

    let families = try #require(catalog.componentFamilies)
    let button = try #require(families.first { $0.id == "button-primary" })
    let preview = try #require(button.preview)
    #expect(preview.layers.count == 3)
    // The surface layer resolves the referenced bg color + radius to concrete values.
    let surface = preview.layers[1]
    #expect(surface.fill == "#B8422E")   // {colors.tertiary}
    #expect(surface.cornerRadius == 4)    // {rounded.sm}
  }

  @Test
  func preservesFigmaRichnessWhenMerging() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    let existing = EaselDesignSystemCatalog(
      name: "Existing",
      summary: "From figma.",
      generatedAt: nil,
      componentGroups: [],
      tokens: EaselDesignSystemTokenSet(
        colors: [], typography: [], spacing: [], radii: [],
        effects: [EaselDesignSystemEffectToken(id: "e", name: "Shadow", kind: "drop-shadow", sourceNodeID: nil, sourceNodeName: nil, confidence: 0.7)]
      ),
      componentFamilies: [
        EaselDesignSystemComponentFamily(id: "card", title: "Card", category: "Surfaces", summary: "", sourcePage: "Page 1", variantCount: 1, variantProperties: [], preview: nil, confidence: 0.6),
      ],
      assets: [EaselDesignSystemAsset(id: "a", name: "logo", relativePath: ".easel/assets/logo.png", kind: "image")]
    )

    let merged = DesignMarkdownCatalogMapper.makeCatalog(from: document, profile: profile(), preservingFrom: existing)

    // Token sections are re-derived from DESIGN.md...
    #expect(merged.tokens?.colors.first?.name == "primary")
    // ...while Figma-only richness is preserved.
    #expect(merged.tokens?.effects.first?.name == "Shadow")
    #expect(merged.componentFamilies?.first?.title == "Card")
    #expect(merged.assets?.first?.name == "logo")
  }

  private func profile() -> EaselDesignSystemProfile {
    EaselDesignSystemProfile(id: UUID(), name: "Test", blurb: "blurb", notes: "", sourceLinks: [], workingDirectory: "/tmp/test", createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
  }
}
