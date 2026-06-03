//
//  WebPreviewDirectoryListingDetector.swift
//  EaselWebInspector
//

import Foundation

enum WebPreviewDirectoryListingDetector {
  /// Python's `http.server` (the scaffold dev server) renders an autoindex page titled
  /// "Directory listing for <path>" whenever the requested directory has no index
  /// document — e.g. while the agent has deleted `index.html` mid-rewrite and is still
  /// generating the replacement. Detect that page from its title so the embedded preview
  /// can show a branded placeholder instead of the raw, unstyled listing.
  static func isDirectoryListing(title: String?) -> Bool {
    guard let title else { return false }
    return title
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .hasPrefix("Directory listing for")
  }
}
