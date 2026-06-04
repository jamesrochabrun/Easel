//
//  SlideDeckScaffoldTests.swift
//  EaselSlidesTests
//

import Testing
@testable import EaselSlides

struct SlideDeckScaffoldTests {
  @Test
  func indexHTMLIncludesSlideContractAndEscapesInputs() {
    let html = SlideDeckScaffold.indexHTML(
      title: "Roadmap & <Plan>",
      designSystemDisplayName: "Airbnb \"Plus\""
    )

    #expect(html.contains("Roadmap &amp; &lt;Plan&gt;"))
    #expect(html.contains("Airbnb &quot;Plus&quot;"))
    #expect(html.contains("data-easel-deck"))
    #expect(html.contains("data-easel-slide"))
    #expect(html.contains("data-title=\"Opening\""))
    #expect(html.contains("<script src=\"./deck-stage.js\"></script>"))
  }

  @Test
  func deckStageJavaScriptTargetsSlideMarkers() {
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("[data-easel-slide]"))
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("ArrowRight"))
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("hashchange"))
  }

  @Test
  func contractSummaryNamesRequiredMarkers() {
    #expect(SlideDeckContract.authoringSummary.contains("section[data-easel-slide]"))
    #expect(SlideDeckContract.authoringSummary.contains("data-easel-deck"))
    #expect(SlideDeckContract.authoringSummary.contains("data-title"))
  }
}
