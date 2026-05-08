//
//  CodexMessageMapper.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

enum CodexMessageMapper {
  static func commandToolUse(command: String) -> ChatMessage {
    let displayCommand = shortenCommand(command)
    return MessageFactory.toolUseMessage(
      toolName: "Bash",
      input: displayCommand,
      toolInputData: ToolInputData(parameters: ["command": displayCommand])
    )
  }

  static func commandToolResult(output: String?, exitCode: Int?) -> ChatMessage {
    let code = exitCode ?? 0
    let status = code == 0 ? "exit 0" : "exit \(code)"
    let trimmedOutput = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let content = trimmedOutput.isEmpty ? status : "\(status)\n\(trimmedOutput)"
    let isError = code != 0

    return ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: content,
      messageType: isError ? .toolError : .toolResult,
      toolName: "Bash",
      isError: isError
    )
  }

  static func mcpToolUse(toolName: String?, arguments: [String: AnyCodable]?) -> ChatMessage {
    let name = toolName?.isEmpty == false ? toolName! : "MCPTool"
    let parameters = stringParameters(from: arguments)
    let input = parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: "\n")

    return MessageFactory.toolUseMessage(
      toolName: name,
      input: input,
      toolInputData: parameters.isEmpty ? nil : ToolInputData(parameters: parameters)
    )
  }

  static func mcpToolResult(toolName: String?, result: String?, isError: Bool = false) -> ChatMessage {
    let name = toolName?.isEmpty == false ? toolName! : "MCPTool"
    let content = result?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? result! : "Completed"

    return ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: content,
      messageType: isError ? .toolError : .toolResult,
      toolName: name,
      isError: isError
    )
  }

  static func fileChangeToolUse(changes: [CodexFileChange]?, legacyPath: String?) -> ChatMessage? {
    let paths = changedPaths(changes: changes, legacyPath: legacyPath)
    guard !paths.isEmpty else { return nil }

    let primaryPath = paths[0]
    let input = paths.joined(separator: "\n")

    return MessageFactory.toolUseMessage(
      toolName: "FileChange",
      input: input,
      toolInputData: ToolInputData(parameters: ["file_path": primaryPath])
    )
  }

  static func fileChangeToolResult(changes: [CodexFileChange]?, legacyPath: String?) -> ChatMessage? {
    let paths = changedPaths(changes: changes, legacyPath: legacyPath)
    guard !paths.isEmpty else { return nil }

    let content = paths.count == 1 ? "Changed \(paths[0])" : "Changed \(paths.count) files"
    return ChatMessage(
      role: .toolResult,
      content: content,
      messageType: .toolResult,
      toolName: "FileChange"
    )
  }

  static func webSearchToolUse(query: String?) -> ChatMessage {
    let searchQuery = query?.isEmpty == false ? query! : "Search"
    return MessageFactory.toolUseMessage(
      toolName: "WebSearch",
      input: searchQuery,
      toolInputData: ToolInputData(parameters: ["query": searchQuery])
    )
  }

  static func webSearchToolResult(resultCount: Int) -> ChatMessage {
    ChatMessage(
      role: .toolResult,
      content: "Found \(resultCount) results",
      messageType: .toolResult,
      toolName: "WebSearch"
    )
  }

  static func todoToolUse(items: [CodexTodoItem]?) -> ChatMessage? {
    guard let items, !items.isEmpty else { return nil }

    let lines = items.map { item in
      let status = item.status ?? "pending"
      let content = item.content ?? item.id ?? "Todo"
      return "[\(status)] \(content)"
    }
    let input = lines.joined(separator: "\n")

    return MessageFactory.toolUseMessage(
      toolName: "TodoWrite",
      input: input,
      toolInputData: ToolInputData(parameters: ["todos": input])
    )
  }

  static func stringParameters(from arguments: [String: AnyCodable]?) -> [String: String] {
    guard let arguments else { return [:] }

    var parameters: [String: String] = [:]
    for (key, value) in arguments {
      parameters[key] = stringValue(from: value.value)
    }
    return parameters
  }

  static func shortenCommand(_ command: String) -> String {
    if command.hasPrefix("/bin/zsh -lc ") {
      var shortened = String(command.dropFirst("/bin/zsh -lc ".count))
      if (shortened.hasPrefix("\"") && shortened.hasSuffix("\"")) ||
        (shortened.hasPrefix("'") && shortened.hasSuffix("'")) {
        shortened = String(shortened.dropFirst().dropLast())
      }
      return shortened
    }
    return command
  }

  private static func changedPaths(changes: [CodexFileChange]?, legacyPath: String?) -> [String] {
    var paths = changes?.compactMap(\.path) ?? []
    if let legacyPath, !legacyPath.isEmpty {
      paths.append(legacyPath)
    }
    return Array(Set(paths)).sorted()
  }

  private static func stringValue(from value: Any) -> String {
    if let string = value as? String {
      return string
    }

    if JSONSerialization.isValidJSONObject(value),
       let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
       let string = String(data: data, encoding: .utf8) {
      return string
    }

    return String(describing: value)
  }
}
