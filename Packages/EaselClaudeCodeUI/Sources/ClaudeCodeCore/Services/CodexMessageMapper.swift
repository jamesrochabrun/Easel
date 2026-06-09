//
//  CodexMessageMapper.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

enum CodexMessageMapper {
  static func commandToolUse(command: String, itemID: String?) -> ChatMessage {
    let displayCommand = shortenCommand(command)
    return MessageFactory.toolUseMessage(
      toolName: "Bash",
      input: displayCommand,
      toolInputData: ToolInputData(parameters: ["command": displayCommand]),
      toolUseID: itemID
    )
  }

  static func commandToolResult(output: String?, exitCode: Int?, itemID: String?) -> ChatMessage {
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
      toolUseID: itemID,
      isError: isError
    )
  }

  static func mcpToolUse(toolName: String?, arguments: [String: AnyCodable]?, itemID: String?) -> ChatMessage {
    let name = toolName?.isEmpty == false ? toolName! : "MCPTool"
    let parameters = stringParameters(from: arguments)
    let input = parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: "\n")

    return MessageFactory.toolUseMessage(
      toolName: name,
      input: input,
      toolInputData: parameters.isEmpty ? nil : ToolInputData(parameters: parameters),
      toolUseID: itemID
    )
  }

  static func mcpToolResult(toolName: String?, result: String?, itemID: String?, isError: Bool = false) -> ChatMessage {
    let name = toolName?.isEmpty == false ? toolName! : "MCPTool"
    let content = result?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? result! : "Completed"

    return ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: content,
      messageType: isError ? .toolError : .toolResult,
      toolName: name,
      toolUseID: itemID,
      isError: isError
    )
  }

  static func fileChangeToolUse(changes: [CodexFileChange]?, legacyPath: String?, itemID: String?) -> ChatMessage? {
    let paths = changedPaths(changes: changes, legacyPath: legacyPath)
    guard !paths.isEmpty else { return nil }

    let primaryPath = paths[0]
    let input = paths.joined(separator: "\n")

    return MessageFactory.toolUseMessage(
      toolName: "FileChange",
      input: input,
      toolInputData: ToolInputData(parameters: ["file_path": primaryPath]),
      toolUseID: itemID
    )
  }

  static func fileChangeToolResult(changes: [CodexFileChange]?, legacyPath: String?, itemID: String?) -> ChatMessage? {
    let paths = changedPaths(changes: changes, legacyPath: legacyPath)
    guard !paths.isEmpty else { return nil }

    let content = paths.count == 1 ? "Changed \(paths[0])" : "Changed \(paths.count) files"
    return ChatMessage(
      role: .toolResult,
      content: content,
      messageType: .toolResult,
      toolName: "FileChange",
      toolUseID: itemID
    )
  }

  static func webSearchToolUse(query: String?, itemID: String?) -> ChatMessage {
    let searchQuery = query?.isEmpty == false ? query! : "Search"
    return MessageFactory.toolUseMessage(
      toolName: "WebSearch",
      input: searchQuery,
      toolInputData: ToolInputData(parameters: ["query": searchQuery]),
      toolUseID: itemID
    )
  }

  static func webSearchToolResult(resultCount: Int, itemID: String?) -> ChatMessage {
    ChatMessage(
      role: .toolResult,
      content: "Found \(resultCount) results",
      messageType: .toolResult,
      toolName: "WebSearch",
      toolUseID: itemID
    )
  }

  static func todoToolUse(items: [CodexTodoItem]?, itemID: String?) -> ChatMessage? {
    guard let items, !items.isEmpty else { return nil }

    let input = todoChecklistMarkdown(from: items)

    return MessageFactory.toolUseMessage(
      toolName: "TodoWrite",
      input: input,
      toolInputData: ToolInputData(parameters: ["todos": input]),
      toolUseID: itemID
    )
  }

  /// Codex emits the plan as a single `todo_list` item with no follow-up result.
  /// Pair the tool use with a result so the card settles instead of showing a
  /// perpetual "Working" spinner once the turn's plan snapshot is in.
  static func todoToolResult(items: [CodexTodoItem]?, itemID: String?) -> ChatMessage? {
    guard let items, !items.isEmpty else { return nil }

    let done = items.filter { $0.completed == true }.count
    return ChatMessage(
      role: .toolResult,
      content: "Plan updated · \(done)/\(items.count) done",
      messageType: .toolResult,
      toolName: "TodoWrite",
      toolUseID: itemID
    )
  }

  /// Renders todos as a markdown checklist (`- [x]` / `- [ ]`) so the shared todo
  /// renderer shows real checkboxes and labels rather than raw status tags.
  private static func todoChecklistMarkdown(from items: [CodexTodoItem]) -> String {
    items.map { item in
      let checkbox = item.completed == true ? "- [x]" : "- [ ]"
      let label = item.text?.trimmingCharacters(in: .whitespacesAndNewlines)
      return "\(checkbox) \(label?.isEmpty == false ? label! : "Todo")"
    }
    .joined(separator: "\n")
  }

  static func stringParameters(from arguments: [String: AnyCodable]?) -> [String: String] {
    guard let arguments else { return [:] }

    var parameters: [String: String] = [:]
    for (key, value) in arguments {
      parameters[key] = stringValue(from: value.value)
    }
    return parameters
  }

  /// Whether a codex shell command has any content worth showing.
  ///
  /// Codex occasionally emits no-op executions whose script is empty
  /// (e.g. `/bin/zsh -lc ''`). Those carry no action and must not surface as cards.
  static func isDisplayableCommand(_ command: String) -> Bool {
    !shortenCommand(command).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  static func shortenCommand(_ command: String) -> String {
    for prefix in ["/bin/zsh -lc ", "/bin/bash -lc ", "/bin/sh -lc ", "zsh -lc ", "bash -lc ", "sh -lc "] {
      if command.hasPrefix(prefix) {
        return unquoted(String(command.dropFirst(prefix.count)))
      }
    }

    return command
  }

  private static func unquoted(_ value: String) -> String {
    var shortened = value
    if (shortened.hasPrefix("\"") && shortened.hasSuffix("\"")) ||
      (shortened.hasPrefix("'") && shortened.hasSuffix("'")) {
      shortened = String(shortened.dropFirst().dropLast())
    }
    return shortened
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
