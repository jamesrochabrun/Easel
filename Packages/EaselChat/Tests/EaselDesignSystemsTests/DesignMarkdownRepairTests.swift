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
  func passesThroughValidDocumentUnchanged() throws {
    let result = try DesignMarkdownRepair.parse(DesignMarkdownFixtures.heritage, fallbackName: nil)
    #expect(result.didRepair == false)
    #expect(result.document.name == "Heritage")
  }
}
