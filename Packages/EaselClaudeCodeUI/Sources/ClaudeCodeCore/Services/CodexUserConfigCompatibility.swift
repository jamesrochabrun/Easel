//
//  CodexUserConfigCompatibility.swift
//  ClaudeCodeUI
//

import Foundation

enum CodexUserConfigCompatibility {
  private static let unsupportedReasoningValues: Set<String> = ["xhigh"]
  private static let reasoningKeys: Set<String> = [
    "model_reasoning_effort",
    "plan_mode_reasoning_effort",
  ]

  static func compatibleConfigOverrides(homeDirectory: String = NSHomeDirectory()) -> [String: String] {
    let configPath = "\(homeDirectory)/.codex/config.toml"
    guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return [:]
    }

    var overrides: [String: String] = [:]

    if containsUnsupportedReasoningEffort(contents) {
      overrides["model_reasoning_effort"] = "\"high\""
      overrides["plan_mode_reasoning_effort"] = "\"high\""
    }

    if containsTUITable(contents), !containsTUIDisableMouseCapture(contents) {
      overrides["tui.disable_mouse_capture"] = "false"
    }

    return overrides
  }

  static func containsUnsupportedReasoningEffort(_ contents: String) -> Bool {
    contents
      .split(whereSeparator: \.isNewline)
      .contains { rawLine in
        let line = lineWithoutComment(String(rawLine))
        guard let (key, value) = keyValuePair(from: line), reasoningKeys.contains(key) else {
          return false
        }
        return unsupportedReasoningValues.contains(value)
      }
  }

  private static func keyValuePair(from line: String) -> (key: String, value: String)? {
    let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }

    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let value = parts[1]
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      .lowercased()

    return (key, value)
  }

  private static func lineWithoutComment(_ line: String) -> String {
    guard let commentStart = line.firstIndex(of: "#") else { return line }
    return String(line[..<commentStart])
  }

  private static func containsTUITable(_ contents: String) -> Bool {
    contents
      .split(whereSeparator: \.isNewline)
      .contains { rawLine in
        let line = lineWithoutComment(String(rawLine))
          .trimmingCharacters(in: .whitespacesAndNewlines)
        return line == "[tui]" || line.hasPrefix("[tui.")
      }
  }

  private static func containsTUIDisableMouseCapture(_ contents: String) -> Bool {
    contents
      .split(whereSeparator: \.isNewline)
      .contains { rawLine in
        let line = lineWithoutComment(String(rawLine))
        guard let (key, _) = keyValuePair(from: line) else { return false }
        return key == "disable_mouse_capture" || key == "tui.disable_mouse_capture"
      }
  }
}
