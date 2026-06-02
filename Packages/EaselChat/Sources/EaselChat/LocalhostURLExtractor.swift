//
//  LocalhostURLExtractor.swift
//  EaselChat
//

import EaselKit
import Foundation

protocol URLExtracting {
  func extractPreviewURL(from text: String) -> URL?
}

struct LocalhostURLExtractor: URLExtracting {

  func extractPreviewURL(from text: String) -> URL? {
    LocalhostPreviewURLSanitizer.extractLastURL(from: text)
  }
}
