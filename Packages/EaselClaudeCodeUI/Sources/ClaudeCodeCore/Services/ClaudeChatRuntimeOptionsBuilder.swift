//
//  ClaudeChatRuntimeOptionsBuilder.swift
//  ClaudeCodeUI
//

import ClaudeCodeSDK
import Foundation

enum ClaudeToolPatternParser {
  static func parse(_ raw: String?) -> [String] {
    guard let raw, !raw.isEmpty else { return [] }
    return raw
      .split(whereSeparator: { $0 == "," || $0.isNewline })
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

@MainActor
struct ClaudeChatRuntimeOptionsBuilder {
  static let defaultDisallowedTools = [
    "AskUserQuestion",
    "Askuserquestion",
    "askUserQuestion",
    "askuserquestion"
  ]

  let globalPreferences: GlobalPreferencesStorage
  let systemPromptPrefix: String?

  func makeOptions() -> ClaudeCodeOptions {
    var options = ClaudeCodeOptions()

    if let model = normalizedOptionalArgument(globalPreferences.claudeModel) {
      options.model = model
    }

    let allowedTools = ClaudeToolPatternParser.parse(globalPreferences.claudeAllowedTools)
      .filter { !Self.isDefaultDisallowedTool($0) }
    if !allowedTools.isEmpty {
      options.allowedTools = allowedTools
    }

    let deniedTools = mergedToolPatterns(
      ClaudeToolPatternParser.parse(globalPreferences.claudeDisallowedTools),
      globalPreferences.disallowedTools,
      Self.defaultDisallowedTools
    )
    if !deniedTools.isEmpty {
      options.disallowedTools = deniedTools
    }

    if !globalPreferences.systemPrompt.isEmpty {
      options.systemPrompt = globalPreferences.systemPrompt
    }

    var combinedAppendPrompt = systemPromptPrefix ?? ""
    if !combinedAppendPrompt.isEmpty && !globalPreferences.appendSystemPrompt.isEmpty {
      combinedAppendPrompt += "\n"
    }
    combinedAppendPrompt += globalPreferences.appendSystemPrompt

    if !combinedAppendPrompt.isEmpty {
      options.appendSystemPrompt = combinedAppendPrompt
    }

    if !globalPreferences.mcpConfigPath.isEmpty {
      options.mcpConfigPath = globalPreferences.mcpConfigPath
    }

    options.permissionMode = .bypassPermissions
    return options
  }

  private func normalizedOptionalArgument(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func isDefaultDisallowedTool(_ tool: String) -> Bool {
    let normalized = tool.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return defaultDisallowedTools.contains { $0.lowercased() == normalized }
  }

  private func mergedToolPatterns(_ groups: [String]...) -> [String] {
    var merged: [String] = []
    var seen = Set<String>()

    for tool in groups.flatMap({ $0 }) {
      let trimmed = tool.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
      merged.append(trimmed)
    }

    return merged
  }
}
