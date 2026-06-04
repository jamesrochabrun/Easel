//
//  SlideDeckThumbnailRenderPlan.swift
//  EaselSlides
//

import CoreGraphics
import Foundation

enum SlideDeckThumbnailRenderPlan {
  static let snapshotWidth: CGFloat = 192
  static let fontReadinessTimeoutMilliseconds = 40

  static func orderedSlides(
    from slides: [SlideDeckSlide],
    selectedIndex: Int
  ) -> [SlideDeckSlide] {
    guard let selectedOffset = slides.firstIndex(where: { $0.index == selectedIndex }) else {
      return slides
    }

    return slides
      .enumerated()
      .sorted { lhs, rhs in
        let lhsDistance = abs(lhs.offset - selectedOffset)
        let rhsDistance = abs(rhs.offset - selectedOffset)

        if lhsDistance != rhsDistance {
          return lhsDistance < rhsDistance
        }

        return lhs.offset < rhs.offset
      }
      .map(\.element)
  }
}
