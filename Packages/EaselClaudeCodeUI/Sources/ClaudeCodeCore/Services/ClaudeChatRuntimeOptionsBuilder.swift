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
  var studioMCP: StudioMCPConfiguration?
  var activeSessionId: String?

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

    var appendParts: [String] = []
    if let systemPromptPrefix, !systemPromptPrefix.isEmpty {
      appendParts.append(systemPromptPrefix)
    }
    if let guidance = studioMCP?.agentGuidance, !guidance.isEmpty {
      appendParts.append(guidance)
    }
    if !globalPreferences.appendSystemPrompt.isEmpty {
      appendParts.append(globalPreferences.appendSystemPrompt)
    }
    let combinedAppendPrompt = appendParts.joined(separator: "\n")

    if !combinedAppendPrompt.isEmpty {
      options.appendSystemPrompt = combinedAppendPrompt
    }

    configureMCP(&options)

    options.permissionMode = .bypassPermissions
    return options
  }

  /// The SDK prefers `mcpConfigPath` over inline `mcpServers`, so the Studio
  /// server rides inline only when the user has no config file of their own;
  /// otherwise both are merged into a derived file. A merge failure falls back
  /// to the user's config untouched — Studio never breaks the session.
  private func configureMCP(_ options: inout ClaudeCodeOptions) {
    let userConfigPath = globalPreferences.mcpConfigPath

    guard let studioMCP else {
      if !userConfigPath.isEmpty {
        options.mcpConfigPath = userConfigPath
      }
      return
    }

    let environment = studioMCP.environment(provider: "claude", sessionId: activeSessionId)

    if userConfigPath.isEmpty {
      options.mcpServers = [
        StudioMCPConfiguration.serverName: .stdio(McpStdioServerConfig(
          command: studioMCP.serverPath,
          args: ["mcp-server"],
          env: environment
        )),
      ]
      return
    }

    let mergedPath = StudioMCPConfigMerger.writeMergedConfig(
      userConfigPath: userConfigPath,
      serverPath: studioMCP.serverPath,
      environment: environment,
      outputDirectory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first?.appendingPathComponent("ClaudeCodeUI", isDirectory: true)
        ?? FileManager.default.temporaryDirectory
    )
    options.mcpConfigPath = mergedPath ?? userConfigPath
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
