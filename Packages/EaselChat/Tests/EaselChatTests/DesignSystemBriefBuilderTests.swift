//
//  DesignSystemBriefBuilderTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

struct DesignSystemBriefBuilderTests {

  @Test
  func markdownIncludesTokensComponentsAndDisclaimer() {
    let catalog = EaselDesignSystemCatalog(
      name: "Plus UI",
      summary: "Local snapshot",
      generatedAt: nil,
      componentGroups: [],
      disclaimer: "Parsed locally from .fig.",
      tokens: EaselDesignSystemTokenSet(
        colors: [
          EaselDesignSystemColorToken(id: "c1", name: "Primary", hex: "#0055FF", sourceNodeID: nil, sourceNodeName: nil, confidence: 0.8)
        ],
        typography: [
          EaselDesignSystemTypographyToken(id: "t1", name: "Body", fontFamily: "Inter", fontStyle: "Regular", fontSize: 16, sourceNodeID: nil, sourceNodeName: nil, confidence: 0.8)
        ],
        spacing: [
          EaselDesignSystemNumberToken(id: "s1", name: "sm", value: 8, unit: "px", sourceNodeID: nil, sourceNodeName: nil, confidence: 0.7)
        ],
        radii: [],
        effects: []
      ),
      componentFamilies: [
        EaselDesignSystemComponentFamily(
          id: "f1",
          title: "Button",
          category: "Buttons",
          summary: "",
          sourcePage: nil,
          variantCount: 3,
          variantProperties: [EaselDesignSystemVariantProperty(id: "kind", name: "Kind", values: ["filled", "outlined"])],
          confidence: 0.9
        )
      ]
    )

    let markdown = DesignSystemBriefBuilder.markdown(
      displayName: "Plus UI",
      detail: "A free Figma UI kit",
      notes: "Warm, rounded brand",
      catalog: catalog
    )

    #expect(markdown.contains("# Design system: Plus UI"))
    #expect(markdown.contains("A free Figma UI kit"))
    #expect(markdown.contains("Parsed locally from .fig."))
    #expect(markdown.contains("#0055FF"))
    #expect(markdown.contains("Inter, Regular, 16px"))
    #expect(markdown.contains("**Button** (Buttons) — 3 variants"))
    #expect(markdown.contains("Kind: filled, outlined"))
    #expect(markdown.contains("Warm, rounded brand"))
  }

  @Test
  func markdownDegradesWhenCatalogMissing() {
    let markdown = DesignSystemBriefBuilder.markdown(
      displayName: "Brand",
      detail: nil,
      notes: nil,
      catalog: nil
    )

    #expect(markdown.contains("# Design system: Brand"))
    #expect(markdown.contains("still being extracted"))
  }
}
