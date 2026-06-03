//
//  SlideDeckMetadata.swift
//  EaselWebInspector
//

import CoreGraphics
import Foundation

enum SlideDeckRenderMetrics {
  static let renderSize = CGSize(width: 1280, height: 720)
  static let aspectRatio: CGFloat = renderSize.width / renderSize.height
}

struct SlideDeckMetadata: Equatable, Sendable {
  static let empty = SlideDeckMetadata(slides: [])

  let slides: [SlideDeckSlide]

  var isEmpty: Bool {
    slides.isEmpty
  }
}

struct SlideDeckSlide: Identifiable, Equatable, Sendable {
  let index: Int
  let title: String

  var id: Int {
    index
  }
}

enum SlideDeckMetadataParser {
  static func metadata(from javaScriptResult: Any?) -> SlideDeckMetadata {
    let records = records(from: javaScriptResult)
    let slides = records.compactMap(parseSlide)
    return SlideDeckMetadata(slides: slides)
  }

  private static func records(from javaScriptResult: Any?) -> [[String: Any]] {
    if let records = javaScriptResult as? [[String: Any]] {
      return records
    }

    if let records = javaScriptResult as? [NSDictionary] {
      return records.compactMap { dictionary in
        dictionary as? [String: Any]
      }
    }

    if let array = javaScriptResult as? NSArray {
      return array.compactMap { item in
        item as? [String: Any]
      }
    }

    return []
  }

  private static func parseSlide(_ record: [String: Any]) -> SlideDeckSlide? {
    guard let index = integerValue(from: record["index"]) else {
      return nil
    }

    let title = (record["title"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = title?.isEmpty == false ? title : "Slide \(index + 1)"

    return SlideDeckSlide(
      index: index,
      title: resolvedTitle ?? "Slide \(index + 1)"
    )
  }

  private static func integerValue(from value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }

    if let value = value as? Double {
      return Int(value)
    }

    if let value = value as? NSNumber {
      return value.intValue
    }

    return nil
  }
}

struct SlideDeckThumbnailCacheKey: Equatable, Sendable {
  let url: URL
  let reloadToken: UUID
  let slideCount: Int
}
