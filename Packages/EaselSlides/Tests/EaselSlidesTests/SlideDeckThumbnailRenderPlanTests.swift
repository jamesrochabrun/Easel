//
//  SlideDeckThumbnailRenderPlanTests.swift
//  EaselSlidesTests
//

import Testing
@testable import EaselSlides

@Suite("SlideDeckThumbnailRenderPlan")
struct SlideDeckThumbnailRenderPlanTests {
  @Test("Prioritizes the selected slide")
  func prioritizesSelectedSlide() {
    let slides = (0..<5).map { index in
      SlideDeckSlide(index: index, title: "Slide \(index + 1)")
    }

    let orderedSlides = SlideDeckThumbnailRenderPlan.orderedSlides(
      from: slides,
      selectedIndex: 3
    )

    #expect(orderedSlides.map(\.index) == [3, 2, 4, 1, 0])
  }

  @Test("Preserves source order when selected slide is missing")
  func preservesSourceOrderForMissingSelectedSlide() {
    let slides = [
      SlideDeckSlide(index: 10, title: "Intro"),
      SlideDeckSlide(index: 20, title: "Plan"),
      SlideDeckSlide(index: 30, title: "Close"),
    ]

    let orderedSlides = SlideDeckThumbnailRenderPlan.orderedSlides(
      from: slides,
      selectedIndex: 0
    )

    #expect(orderedSlides == slides)
  }
}
