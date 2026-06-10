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
    #expect(html.contains("easel-slide-safe"))
    #expect(html.contains("data-layout=\"hero\""))
    #expect(html.contains("data-layout=\"content\""))
    #expect(html.contains("<script src=\"./deck-stage.js\"></script>"))
  }

  @Test
  func indexHTMLUsesFullBleedDeckStage() {
    let html = SlideDeckScaffold.indexHTML(
      title: "Roadmap",
      designSystemDisplayName: "Default"
    )

    #expect(html.contains("width: 100vw;"))
    #expect(html.contains("height: 100vh;"))
    #expect(html.contains("border-radius: 0;"))
    #expect(html.contains("box-shadow: none;"))
    #expect(html.contains("overflow: hidden;"))
    #expect(html.contains("clip-path: inset(0);"))
    #expect(html.contains("contain: paint;"))
    #expect(html.contains("place-items: center") == false)
    #expect(html.contains("width: min(100vw") == false)
    #expect(html.contains("calc(100vh * 16 / 9)") == false)
  }

  @Test
  func deckStageJavaScriptTargetsSlideMarkers() {
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("[data-easel-slide]"))
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("ArrowRight"))
    #expect(SlideDeckScaffold.deckStageJavaScript.contains("hashchange"))
  }

  @Test
  func layoutTemplateProvidesReusableSafeSlideClasses() {
    let css = SlideDeckScaffold.layoutTemplateCSS
    let markdown = SlideDeckScaffold.layoutTemplateMarkdown

    #expect(css.contains(".easel-slide-safe"))
    #expect(css.contains("grid-template-rows: auto minmax(0, 1fr) auto"))
    #expect(css.contains("data-density=\"dense\""))
    #expect(css.contains("overflow: hidden"))
    #expect(markdown.contains("# Easel Slide Template"))
    #expect(markdown.contains("1280x720"))
    #expect(markdown.contains("Put all visible slide content inside `.easel-slide-safe`"))
    #expect(markdown.contains("<section data-easel-slide"))
  }

  @Test
  func deckStageJavaScriptEnforcesFullBleedStage() {
    let script = SlideDeckScaffold.deckStageJavaScript

    #expect(script.contains("easel-slide-deck-stage-style"))
    #expect(script.contains("[data-easel-deck]"))
    #expect(script.contains("width: 100vw !important"))
    #expect(script.contains("height: 100vh !important"))
    #expect(script.contains("padding: 0 !important"))
    #expect(script.contains("border-radius: 0 !important"))
    #expect(script.contains("box-shadow: none !important"))
    #expect(script.contains("overflow: hidden !important"))
    #expect(script.contains("clip-path: inset(0) !important"))
    #expect(script.contains("contain: paint !important"))
  }

  @Test
  func contractSummaryNamesRequiredMarkers() {
    #expect(SlideDeckContract.authoringSummary.contains("section[data-easel-slide]"))
    #expect(SlideDeckContract.authoringSummary.contains("data-easel-deck"))
    #expect(SlideDeckContract.authoringSummary.contains("data-title"))
    #expect(SlideDeckContract.authoringSummary.contains("full-bleed"))
    #expect(SlideDeckContract.authoringSummary.contains("no body padding"))
    #expect(SlideDeckContract.authoringSummary.contains("box shadow"))
    #expect(SlideDeckContract.authoringSummary.contains("clip to the square 16:9 slide bounds"))
    #expect(SlideDeckContract.authoringSummary.contains("inner rounded card"))
    #expect(SlideDeckContract.authoringSummary.contains("resources/SLIDE_TEMPLATE.md"))
    #expect(SlideDeckContract.authoringSummary.contains("1280x720"))
    #expect(SlideDeckContract.authoringSummary.contains("without vertical or horizontal overflow"))
    #expect(SlideDeckContract.authoringSummary.contains("minmax(0, 1fr)"))
    #expect(SlideDeckContract.authoringSummary.contains("visible immediately in thumbnails"))
  }
}
