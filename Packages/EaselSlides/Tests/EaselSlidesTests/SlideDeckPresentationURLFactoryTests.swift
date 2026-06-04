//
//  SlideDeckPresentationURLFactoryTests.swift
//  EaselSlidesTests
//

import Foundation
import Testing
@testable import EaselSlides

@Suite("SlideDeckPresentationURLFactory")
struct SlideDeckPresentationURLFactoryTests {
  @Test("Adds a one-based slide hash")
  func addsOneBasedSlideHash() {
    let url = URL(string: "http://localhost:4100/index.html")!

    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: 2
    )

    #expect(presentationURL.absoluteString == "http://localhost:4100/index.html#slide-3")
  }

  @Test("Preserves query items when adding slide hash")
  func preservesQueryItems() {
    let url = URL(string: "http://localhost:4100/?theme=dark&easelReload=1")!

    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: 0
    )

    #expect(presentationURL.absoluteString == "http://localhost:4100/?theme=dark&easelReload=1#slide-1")
  }

  @Test("Replaces existing hash")
  func replacesExistingHash() {
    let url = URL(string: "http://localhost:4100/#slide-4")!

    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: 1
    )

    #expect(presentationURL.absoluteString == "http://localhost:4100/#slide-2")
  }

  @Test("Clamps negative indexes to first slide")
  func clampsNegativeIndexes() {
    let url = URL(string: "http://localhost:4100/")!

    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: -4
    )

    #expect(presentationURL.absoluteString == "http://localhost:4100/#slide-1")
  }
}
