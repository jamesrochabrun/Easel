//
//  LocalhostDetectionService.swift
//  Easel
//
//  Protocol-based localhost URL detection. Current implementation parses terminal
//  output; can be swapped to MCP-based detection later by conforming to the same protocol.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.easel", category: "LocalhostDetector")

// MARK: - Protocol

protocol LocalhostDetectionService: AnyObject {
  var detectedURL: URL? { get }
  func processTerminalOutput(_ text: String)
  func reset()
}

// MARK: - Terminal Output Implementation

@Observable
final class TerminalOutputLocalhostDetector: LocalhostDetectionService {
  private(set) var detectedURL: URL?
  private var lineBuffer = ""

  private static let localhostPattern = try! NSRegularExpression(
    pattern: #"https?://(?:localhost|127\.0\.0\.1):(\d+)(?:/\S*)?"#,
    options: []
  )

  private static let ansiPattern = try! NSRegularExpression(
    pattern: #"\x1b\[[0-9;]*[a-zA-Z]"#,
    options: []
  )

  func processTerminalOutput(_ text: String) {
    lineBuffer.append(text)

    // Split on newlines; keep last incomplete fragment in buffer
    let lines = lineBuffer.components(separatedBy: .newlines)
    guard lines.count > 1 else {
      // No complete line yet — also try matching the buffer as-is
      // in case the URL arrives in a single chunk without trailing newline
      matchLine(stripANSI(lineBuffer))
      return
    }

    // Process all complete lines (everything except the last fragment)
    for line in lines.dropLast() {
      let cleaned = stripANSI(line)
      matchLine(cleaned)
    }

    // Keep the last (potentially incomplete) fragment
    lineBuffer = lines.last ?? ""
  }

  func reset() {
    detectedURL = nil
    lineBuffer = ""
    logger.info("Detector reset")
  }

  // MARK: - Private

  private func stripANSI(_ text: String) -> String {
    let range = NSRange(text.startIndex..., in: text)
    return Self.ansiPattern.stringByReplacingMatches(
      in: text, range: range, withTemplate: ""
    )
  }

  private func matchLine(_ line: String) {
    guard !line.isEmpty else { return }

    let range = NSRange(line.startIndex..., in: line)
    guard let match = Self.localhostPattern.firstMatch(in: line, range: range) else { return }
    guard let matchRange = Range(match.range, in: line) else { return }

    let urlString = String(line[matchRange])
    logger.info("URL match found: \(urlString)")

    guard let url = URL(string: urlString), url != detectedURL else { return }
    detectedURL = url
    logger.notice("detectedURL updated → \(url.absoluteString)")
  }
}
