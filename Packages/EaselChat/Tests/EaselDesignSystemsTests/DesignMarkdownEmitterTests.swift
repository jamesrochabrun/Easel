//
//  DesignMarkdownEmitterTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownEmitterTests {

  @Test
  func emitsCanonicalFrontMatterAndQuotesReferences() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    let text = DesignMarkdownEmitter.emit(document)

    #expect(text.hasPrefix("---\n"))
    #expect(text.contains("version: alpha"))
    #expect(text.contains("name: Heritage"))
    // Color values are always quoted.
    #expect(text.contains("  primary: \"#1A1C1E\""))
    // Token references are quoted so YAML doesn't read them as flow maps.
    #expect(text.contains("backgroundColor: \"{colors.tertiary}\""))
    // Plain typography values stay unquoted.
    #expect(text.contains("fontFamily: Public Sans"))
  }

  @Test
  func ordersSectionsCanonically() {
    let document = DesignMarkdown(
      name: "Reorder",
      sections: [
        DesignSection(kind: .components, title: "Components", body: "c"),
        DesignSection(kind: .overview, title: "Overview", body: "o"),
        DesignSection(kind: .colors, title: "Colors", body: "col"),
      ]
    )
    let text = DesignMarkdownEmitter.emit(document)
    let overviewIndex = try! #require(text.range(of: "## Overview")).lowerBound
    let colorsIndex = try! #require(text.range(of: "## Colors")).lowerBound
    let componentsIndex = try! #require(text.range(of: "## Components")).lowerBound
    #expect(overviewIndex < colorsIndex)
    #expect(colorsIndex < componentsIndex)
  }

  @Test
  func preservesUnknownSectionsAtEnd() {
    let document = DesignMarkdown(
      name: "Keep",
      sections: [
        DesignSection(kind: nil, title: "Motion", body: "Animations."),
        DesignSection(kind: .overview, title: "Overview", body: "o"),
      ]
    )
    let text = DesignMarkdownEmitter.emit(document)
    let overviewIndex = try! #require(text.range(of: "## Overview")).lowerBound
    let motionIndex = try! #require(text.range(of: "## Motion")).lowerBound
    #expect(overviewIndex < motionIndex)
  }

  @Test
  func buildsSpecCompliantDocumentFromCatalog() {
    let catalog = EaselDesignSystemCatalog(
      name: "Aurora",
      summary: "A calm productivity palette.",
      generatedAt: nil,
      componentGroups: [],
      tokens: EaselDesignSystemTokenSet(
        colors: [
          color(name: "Ink", hex: "#101317", confidence: 0.95),
          color(name: "Sky", hex: "#3B82F6", confidence: 0.8),
        ],
        typography: [
          type(name: "Heading", family: "Inter", size: 32, style: "Bold"),
          type(name: "Body", family: "Inter", size: 16, style: "Regular"),
        ],
        spacing: [number(name: "space-1", value: 8), number(name: "space-2", value: 16)],
        radii: [number(name: "radius-1", value: 6)],
        effects: [effect(name: "Card Shadow", kind: "drop-shadow")]
      ),
      componentFamilies: [family(title: "Button", category: "Actions")]
    )
    let profile = makeProfile(name: "Aurora", blurb: "A calm productivity tool.")

    let document = DesignMarkdownEmitter.makeDocument(fromCatalog: catalog, profile: profile)

    // Semantic color naming: highest-confidence color becomes `primary`.
    #expect(document.colors.first?.name == "primary")
    #expect(document.colors.first?.value == "#101317")
    #expect(document.colors.contains(where: { $0.name == "secondary" }))

    // Typography ranked largest-first into named levels with mapped weight.
    #expect(document.typography.first?.name == "display-lg")
    #expect(document.typography.first?.fontSize == "32px")
    #expect(document.typography.first?.fontWeight == "700")

    // Effects are rendered into prose, not YAML.
    #expect(document.sections.contains(where: { $0.kind == .elevation }))
    #expect(document.colors.isEmpty == false)

    // The emitted text lints clean (no blocking errors).
    #expect(throws: Never.self) { try DesignMarkdownLinter.validate(document) }
  }

  // MARK: - Builders

  private func color(name: String, hex: String, confidence: Double) -> EaselDesignSystemColorToken {
    EaselDesignSystemColorToken(id: name, name: name, hex: hex, sourceNodeID: nil, sourceNodeName: nil, confidence: confidence)
  }

  private func type(name: String, family: String, size: Double, style: String) -> EaselDesignSystemTypographyToken {
    EaselDesignSystemTypographyToken(id: name, name: name, fontFamily: family, fontStyle: style, fontSize: size, sourceNodeID: nil, sourceNodeName: nil, confidence: 0.9)
  }

  private func number(name: String, value: Double) -> EaselDesignSystemNumberToken {
    EaselDesignSystemNumberToken(id: name, name: name, value: value, unit: "px", sourceNodeID: nil, sourceNodeName: nil, confidence: 0.9)
  }

  private func effect(name: String, kind: String) -> EaselDesignSystemEffectToken {
    EaselDesignSystemEffectToken(id: name, name: name, kind: kind, sourceNodeID: nil, sourceNodeName: nil, confidence: 0.9)
  }

  private func family(title: String, category: String) -> EaselDesignSystemComponentFamily {
    EaselDesignSystemComponentFamily(id: title, title: title, category: category, summary: "", sourcePage: nil, variantCount: 1, variantProperties: [], preview: nil, confidence: 0.9)
  }

  private func makeProfile(name: String, blurb: String) -> EaselDesignSystemProfile {
    EaselDesignSystemProfile(id: UUID(), name: name, blurb: blurb, notes: "", sourceLinks: [], workingDirectory: "/tmp/\(name)", createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
  }
}
