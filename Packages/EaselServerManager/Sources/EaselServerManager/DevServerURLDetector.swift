//
//  DevServerURLDetector.swift
//  EaselServerManager
//

import Foundation

struct DevServerURLDetector {

  private static let ansiPattern = #"\x1B\[[0-9;]*[A-Za-z]"#
  private static let urlPattern = #"https?://(?:localhost|127\.0\.0\.1):\d{1,5}(?:/[^\s\)\]\}\"'*<>]*)?"#

  static func extractURL(from text: String) -> URL? {
    // Strip ANSI escape codes before matching
    let cleaned: String
    if let ansiRegex = try? NSRegularExpression(pattern: ansiPattern) {
      let range = NSRange(text.startIndex..., in: text)
      cleaned = ansiRegex.stringByReplacingMatches(
        in: text, range: range, withTemplate: ""
      )
    } else {
      cleaned = text
    }

    guard let regex = try? NSRegularExpression(pattern: urlPattern) else {
      return nil
    }
    let range = NSRange(cleaned.startIndex..., in: cleaned)
    guard let match = regex.firstMatch(in: cleaned, range: range),
      let matchRange = Range(match.range, in: cleaned)
    else {
      return nil
    }
    let urlString = String(cleaned[matchRange])
      .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
    return URL(string: urlString)
  }
}
