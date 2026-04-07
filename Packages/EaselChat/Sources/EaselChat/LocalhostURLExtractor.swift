//
//  LocalhostURLExtractor.swift
//  EaselChat
//

import Foundation

protocol URLExtracting {
  func extractPreviewURL(from text: String) -> URL?
}

struct LocalhostURLExtractor: URLExtracting {

  func extractPreviewURL(from text: String) -> URL? {
    let pattern = #"https?://(?:localhost|127\.0\.0\.1):\d{1,5}(?:/[^\s\)\]\}\"'*<>]*)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return nil
    }
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, options: [], range: range)
    guard let lastMatch = matches.last,
      let matchRange = Range(lastMatch.range, in: text)
    else {
      return nil
    }
    let urlString = String(text[matchRange])
      .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
    return URL(string: urlString)
  }
}
