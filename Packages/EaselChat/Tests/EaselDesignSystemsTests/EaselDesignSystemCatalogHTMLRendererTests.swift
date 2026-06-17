//
//  EaselDesignSystemCatalogHTMLRendererTests.swift
//  EaselDesignSystemsTests
//

import Testing
@testable import EaselDesignSystems

struct EaselDesignSystemCatalogHTMLRendererTests {

  @Test
  func htmlIncludesThemeModeControlsAndSystemChangeHandling() {
    let html = EaselDesignSystemCatalogHTMLRenderer.html(
      title: "Nimbus",
      blurb: "A calm weather app."
    )

    #expect(html.contains("data-theme-option=\"system\""))
    #expect(html.contains("data-theme-option=\"light\""))
    #expect(html.contains("data-theme-option=\"dark\""))
    #expect(html.contains("easel-design-system-theme"))
    #expect(html.contains("matchMedia(\"(prefers-color-scheme: dark)\")"))
    #expect(html.contains("systemThemeQuery.addEventListener(\"change\""))
    #expect(html.contains(":root[data-theme-mode=\"dark\"]"))
    #expect(html.contains(":root[data-theme-mode=\"light\"]"))
  }

  @Test
  func htmlFiltersNonActionableDiagnosticsWarnings() {
    let html = EaselDesignSystemCatalogHTMLRenderer.html(
      title: "Nimbus",
      blurb: "A calm weather app."
    )

    #expect(html.contains("const hiddenWarnings = new Set(["))
    #expect(html.contains("Component families are grouped by Figma layer name and may be noisy."))
    #expect(html.contains("Tokens are inferred from local node styles, not from a published token library."))
    #expect(html.contains("const warnings = (diag.warnings || []).filter((warning) => !hiddenWarnings.has(warning));"))
    #expect(html.contains("for (const w of warnings)"))
  }
}
