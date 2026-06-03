//
//  SlideDeckMetadataParserTests.swift
//  EaselWebInspectorTests
//

import Foundation
import Testing
@testable import EaselWebInspector

@Suite("SlideDeckMetadataParser")
struct SlideDeckMetadataParserTests {
  @Test("Parses slide records from JavaScript dictionaries")
  func parsesSlideRecords() {
    let metadata = SlideDeckMetadataParser.metadata(from: [
      ["index": 0, "title": "Opening"],
      ["index": 1, "title": " Details "],
    ])

    #expect(metadata.slides == [
      SlideDeckSlide(index: 0, title: "Opening"),
      SlideDeckSlide(index: 1, title: "Details"),
    ])
  }

  @Test("Falls back to slide number for missing or blank titles")
  func fallsBackToSlideNumber() {
    let metadata = SlideDeckMetadataParser.metadata(from: [
      ["index": NSNumber(value: 0), "title": ""],
      ["index": NSNumber(value: 2)],
    ])

    #expect(metadata.slides == [
      SlideDeckSlide(index: 0, title: "Slide 1"),
      SlideDeckSlide(index: 2, title: "Slide 3"),
    ])
  }

  @Test("Ignores malformed records")
  func ignoresMalformedRecords() {
    let metadata = SlideDeckMetadataParser.metadata(from: [
      ["title": "Missing index"],
      ["index": 1, "title": "Valid"],
    ])

    #expect(metadata.slides == [
      SlideDeckSlide(index: 1, title: "Valid"),
    ])
  }

  @Test("Returns empty metadata for unsupported payloads")
  func returnsEmptyMetadataForUnsupportedPayloads() {
    #expect(SlideDeckMetadataParser.metadata(from: nil).isEmpty)
    #expect(SlideDeckMetadataParser.metadata(from: "not slides").isEmpty)
  }

  @Test("Thumbnail cache key changes when reload token changes")
  func thumbnailCacheKeyChangesWithReloadToken() {
    let url = URL(string: "http://localhost:4100/")!
    let first = SlideDeckThumbnailCacheKey(
      url: url,
      reloadToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      slideCount: 2
    )
    let second = SlideDeckThumbnailCacheKey(
      url: url,
      reloadToken: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      slideCount: 2
    )

    #expect(first != second)
  }

  @Test("Thumbnail cache key changes when slide count changes")
  func thumbnailCacheKeyChangesWithSlideCount() {
    let url = URL(string: "http://localhost:4100/")!
    let reloadToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let first = SlideDeckThumbnailCacheKey(url: url, reloadToken: reloadToken, slideCount: 2)
    let second = SlideDeckThumbnailCacheKey(url: url, reloadToken: reloadToken, slideCount: 3)

    #expect(first != second)
  }
}
