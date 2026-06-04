//
//  SlideDeckPresentationControlMetricsTests.swift
//  EaselSlidesTests
//

import Testing
@testable import EaselSlides

struct SlideDeckPresentationControlMetricsTests {

  @Test
  func iconButtonsKeepLargeTapTarget() {
    #expect(SlideDeckPresentationControlMetrics.iconButtonSize >= 32)
  }

  @Test
  func counterKeepsStableWidthBetweenSlideChanges() {
    #expect(SlideDeckPresentationControlMetrics.counterMinWidth >= 56)
  }
}
