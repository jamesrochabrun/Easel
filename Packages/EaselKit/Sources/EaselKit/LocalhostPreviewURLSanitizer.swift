//
//  LocalhostPreviewURLSanitizer.swift
//  EaselKit
//

import Foundation

public enum LocalhostPreviewURLSanitizer {
  private static let ansiPattern = #"\x1B\[[0-9;]*[A-Za-z]"#
  private static let urlPattern = #"https?://(?:localhost|127\.0\.0\.1):\d{1,5}(?:/[^\s\)\]\}\"'`*<>]*)?"#
  private static let trailingCharacters = CharacterSet(charactersIn: ".,;:!?`'\"")
  private static let trailingEncodedCharacters = [
    "%21", // !
    "%22", // "
    "%27", // '
    "%60", // `
  ]

  public static func extractFirstURL(from text: String) -> URL? {
    extractURLs(from: text).first
  }

  public static func extractLastURL(from text: String) -> URL? {
    extractURLs(from: text).last
  }

  private static func extractURLs(from text: String) -> [URL] {
    let cleaned = stripANSIEscapeCodes(from: text)
    guard let regex = try? NSRegularExpression(pattern: urlPattern) else {
      return []
    }

    let range = NSRange(cleaned.startIndex..., in: cleaned)
    return regex.matches(in: cleaned, options: [], range: range).compactMap { match in
      guard let matchRange = Range(match.range, in: cleaned) else {
        return nil
      }
      return sanitizedURL(from: String(cleaned[matchRange]))
    }
  }

  private static func stripANSIEscapeCodes(from text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: ansiPattern) else {
      return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
  }

  private static func sanitizedURL(from candidate: String) -> URL? {
    var urlString = candidate.trimmingCharacters(in: trailingCharacters)

    while let suffix = trailingEncodedCharacters.first(where: {
      urlString.lowercased().hasSuffix($0.lowercased())
    }) {
      urlString.removeLast(suffix.count)
      urlString = urlString.trimmingCharacters(in: trailingCharacters)
    }

    return URL(string: urlString)
  }
}
