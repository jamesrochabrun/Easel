//
//  DevServerURLDetector.swift
//  EaselServerManager
//

import EaselKit
import Foundation

struct DevServerURLDetector {

  static func extractURL(from text: String) -> URL? {
    LocalhostPreviewURLSanitizer.extractFirstURL(from: text)
  }
}
