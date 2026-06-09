//
//  DesignMarkdownLinterTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownLinterTests {

  @Test
  func cleanDocumentValidates() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage)
    #expect(throws: Never.self) { try DesignMarkdownLinter.validate(document) }
  }

  @Test
  func brokenReferenceIsBlockingError() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    let findings = DesignMarkdownLinter.lint(document)
    #expect(findings.contains { $0.rule == "broken-ref" && $0.severity == .error })
    #expect(throws: DesignMarkdownLintError.self) { try DesignMarkdownLinter.validate(document) }
  }

  @Test
  func flagsMissingPrimaryAndTypography() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    let findings = DesignMarkdownLinter.lint(document)
    #expect(findings.contains { $0.rule == "missing-primary" && $0.severity == .warning })
    #expect(findings.contains { $0.rule == "missing-typography" && $0.severity == .warning })
  }

  @Test
  func flagsLowContrastComponent() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    let findings = DesignMarkdownLinter.lint(document)
    let contrast = findings.filter { $0.rule == "contrast-ratio" }
    #expect(contrast.contains { $0.location == "components.card" })
  }

  @Test
  func flagsSectionOrderAndUnknownKeys() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    let findings = DesignMarkdownLinter.lint(document)
    #expect(findings.contains { $0.rule == "section-order" })
    #expect(findings.contains { $0.rule == "unknown-key" && $0.location == "brandTone" })
  }

  @Test
  func acceptsExtendedComponentPropertiesWithoutWarning() {
    let document = DesignMarkdown(
      name: "Extended",
      components: [
        DesignMarkdown.ComponentToken(name: "a", properties: [
          DesignMarkdown.ComponentProperty(key: "description", value: .literal("docs")),
          DesignMarkdown.ComponentProperty(key: "borderColor", value: .literal("#000000")),
          DesignMarkdown.ComponentProperty(key: "cellPadding", value: .literal("8px")),
        ]),
      ]
    )
    // Component properties are free-form; none of them produce unknown-key noise.
    #expect(DesignMarkdownLinter.lint(document).contains { $0.rule == "unknown-key" } == false)
  }

  @Test
  func stillFlagsUnknownTopLevelKeys() throws {
    let document = try DesignMarkdownParser.parse(DesignMarkdownFixtures.imperfect)
    // `brandTone` at the top level is still surfaced (likely a real typo).
    #expect(DesignMarkdownLinter.lint(document).contains { $0.rule == "unknown-key" && $0.location == "brandTone" })
  }

  @Test
  func wcagContrastMath() {
    #expect(WCAGContrast.contrastRatio("#000000", "#FFFFFF").map { Int($0.rounded()) } == 21)
    #expect(WCAGContrast.contrastRatio("#FFFFFF", "#FFFFFF") == 1.0)
    // #767676 on white passes AA; #999999 on white fails.
    let passing = try! #require(WCAGContrast.contrastRatio("#767676", "#FFFFFF"))
    let failing = try! #require(WCAGContrast.contrastRatio("#999999", "#FFFFFF"))
    #expect(passing >= WCAGContrast.aaNormalText)
    #expect(failing < WCAGContrast.aaNormalText)
    // Non-hex colors are not evaluated.
    #expect(WCAGContrast.contrastRatio("oklch(62% 0.18 250)", "#FFFFFF") == nil)
  }
}
