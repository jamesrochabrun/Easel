//
//  SlideDeckPresentationURLFactory.swift
//  EaselSlides
//

import Foundation

enum SlideDeckPresentationURLFactory {
  static func presentationURL(
    for url: URL,
    selectedIndex: Int
  ) -> URL {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.fragment = "slide-\(max(0, selectedIndex) + 1)"
    return components?.url ?? url
  }
}
