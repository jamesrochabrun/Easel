//
//  DesignMarkdownRepairTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownRepairTests {

  @Test
  func synthesizesFrontMatterFromProse() throws {
    let prose = [
      "# Plus UI",
      "",
      "A clean component kit.",
      "",
      "## Colors",
      "- Primary #4F46E5",
      "- Surface #FFFFFF",
    ].joined(separator: "\n")

    let result = try DesignMarkdownRepair.parse(prose, fallbackName: nil)
    #expect(result.didRepair)
    #expect(result.document.name == "Plus UI") // from the first heading
    #expect(result.document.colors.first?.name == "primary")
    #expect(result.document.colors.first?.value == "#4F46E5")
    #expect(result.document.sections.contains { $0.kind == .colors })
  }

  @Test
  func usesFallbackNameAndScrapesColorWhenNoHeading() throws {
    let result = try DesignMarkdownRepair.parse("Just some text with #ABCDEF in it.", fallbackName: "My Kit")
    #expect(result.didRepair)
    #expect(result.document.name == "My Kit")
    #expect(result.document.colors.first?.value == "#ABCDEF")
    // Prose with no `##` section is wrapped under Overview so it isn't lost.
    #expect(result.document.sections.contains { $0.kind == .overview })
  }

  @Test
  func skipsMarkdownHeadingsWhenScrapingColors() throws {
    let result = try DesignMarkdownRepair.parse("## Heading\n\nNo colors here.", fallbackName: "X")
    #expect(result.document.colors.isEmpty)
  }

  @Test
  func synthesizesTokensFromLovableStyleProse() throws {
    let result = try DesignMarkdownRepair.parse(DesignMarkdownFixtures.lovableProse, fallbackName: nil)
    let document = result.document

    #expect(result.didRepair)
    #expect(document.name == "Lovable")
    #expect(document.detail?.contains("radiates warmth") == true)

    let colorsByName = Dictionary(uniqueKeysWithValues: document.colors.map { ($0.name, $0.value) })
    #expect(colorsByName["primary"] == "#F7F4ED")
    #expect(colorsByName["cream"] == "#F7F4ED")
    #expect(colorsByName["charcoal"] == "#1C1C1C")
    #expect(colorsByName["charcoal-40"] == "rgba(28,28,28,0.4)")
    #expect(colorsByName["light-cream"] == "#ECEAE4")

    let displayHero = try #require(document.typography.first { $0.name == "display-hero" })
    #expect(displayHero.fontFamily == "Camera Plain Variable")
    #expect(displayHero.fontSize == "60px")
    #expect(displayHero.fontWeight == "600")
    #expect(displayHero.lineHeight == "1.00-1.10")
    #expect(displayHero.letterSpacing == "-1.5px")
    #expect(document.typography.first { $0.name == "body" }?.fontSize == "16px")

    #expect(document.spacing.map(\.value).prefix(4).elementsEqual(["8px", "10px", "12px", "16px"]))
    let radiiByName = Dictionary(uniqueKeysWithValues: document.rounded.map { ($0.name, $0.value) })
    #expect(radiiByName["micro"] == "4px")
    #expect(radiiByName["full-pill"] == "9999px")

    let primaryButton = try #require(document.components.first { $0.name.contains("primary-dark") })
    #expect(primaryButton.properties.first { $0.key == "backgroundColor" }?.value == .literal("#1c1c1c"))
    #expect(primaryButton.properties.first { $0.key == "textColor" }?.value == .literal("#fcfbf8"))
    #expect(primaryButton.properties.first { $0.key == "rounded" }?.value == .literal("6px"))

    #expect(document.sections.map(\.kind).contains(.typography))
    #expect(document.sections.map(\.kind).contains(.components))
  }

  @Test
  func enrichesSparseValidFrontMatterFromLovableStyleProse() throws {
    let oldRepairOutput = [
      "---",
      "version: alpha",
      "name: Lovable",
      "colors:",
      "  primary: \"#F7F4ED\"",
      "  secondary: \"#1C1C1C\"",
      "  tertiary: \"#ECEAE4\"",
      "  neutral: \"#FCFBF8\"",
      "  accent-1: \"#5F5F5D\"",
      "  accent-2: \"#3B82F6\"",
      "  accent-3: \"#FFFFFF\"",
      "---",
      "",
      DesignMarkdownFixtures.lovableProse,
    ].joined(separator: "\n")

    let result = try DesignMarkdownRepair.parse(oldRepairOutput, fallbackName: nil)
    let document = result.document

    #expect(result.didRepair)
    #expect(result.notes.isEmpty)
    #expect(document.typography.isEmpty == false)
    #expect(document.components.isEmpty == false)
    #expect(document.spacing.isEmpty == false)
    #expect(document.rounded.isEmpty == false)

    let colorsByName = Dictionary(uniqueKeysWithValues: document.colors.map { ($0.name, $0.value) })
    #expect(colorsByName["primary"] == "#F7F4ED")
    #expect(colorsByName["cream"] == "#F7F4ED")
    #expect(colorsByName["charcoal"] == "#1C1C1C")
  }

  @Test
  func addsPrimaryAliasToAlreadyEnrichedColors() throws {
    let alreadyEnrichedOutput = [
      "---",
      "version: alpha",
      "name: Lovable",
      "colors:",
      "  cream: \"#F7F4ED\"",
      "  charcoal: \"#1C1C1C\"",
      "  light-cream: \"#ECEAE4\"",
      "typography:",
      "  display-hero:",
      "    fontFamily: Camera Plain Variable",
      "    fontSize: 60px",
      "    fontWeight: 600",
      "---",
      "",
      "## Colors",
      "",
      "- **Cream** (`#f7f4ed`): Page background.",
    ].joined(separator: "\n")

    let result = try DesignMarkdownRepair.parse(alreadyEnrichedOutput, fallbackName: nil)
    let colorsByName = Dictionary(uniqueKeysWithValues: result.document.colors.map { ($0.name, $0.value) })

    #expect(result.didRepair)
    #expect(colorsByName["primary"] == "#F7F4ED")
    #expect(colorsByName["cream"] == "#F7F4ED")
    #expect(DesignMarkdownLinter.lint(result.document).contains { $0.rule == "missing-primary" } == false)
  }

  @Test
  func passesThroughValidDocumentUnchanged() throws {
    let result = try DesignMarkdownRepair.parse(DesignMarkdownFixtures.heritage, fallbackName: nil)
    #expect(result.didRepair == false)
    #expect(result.document.name == "Heritage")
  }
}
