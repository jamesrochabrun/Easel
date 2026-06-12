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
}
