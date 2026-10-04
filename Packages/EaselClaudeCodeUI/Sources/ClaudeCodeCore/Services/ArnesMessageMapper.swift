//
//  ArnesMessageMapper.swift
//  ClaudeCodeUI
//

import Foundation

/// Maps Arnes `stream-json` events into chat messages, mirroring
/// `CodexMessageMapper` so both CLI harnesses render through the same cards.
enum ArnesMessageMapper {
  /// Arnes tool names are snake_case; map them onto the display names the
  /// message cards already know so Read/Edit/Bash/Task render natively.
  static func displayToolName(_ name: String) -> String {
    switch name {
    case "bash": return "Bash"
    case "read_file": return "Read"
    case "write_file": return "Write"
    case "edit_file": return "Edit"
    case "grep": return "Grep"
    case "glob": return "Glob"
    case "update_plan": return "TodoWrite"
    case "task": return "Task"
    case "think": return "Think"
    case "skill": return "Skill"
    case "web_fetch": return "WebFetch"
    case "view_image": return "ViewImage"
    case "ask_user": return "AskUser"
    case "job": return "Job"
    default: return name
    }
  }

  static func toolUse(name: String, arguments: [String: Any], toolUseID: String) -> ChatMessage {
    let displayName = displayToolName(name)
    let parameters = stringParameters(from: arguments)
    let input = primaryInput(toolName: name, parameters: parameters)

    return MessageFactory.toolUseMessage(
      toolName: displayName,
      input: input,
      toolInputData: parameters.isEmpty ? nil : ToolInputData(parameters: parameters),
      toolUseID: toolUseID
    )
  }

  static func toolResult(name: String, preview: String, toolUseID: String?) -> ChatMessage {
    let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
    let isError = trimmed.hasPrefix("error:")
    return ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: trimmed.isEmpty ? "Completed" : trimmed,
      messageType: isError ? .toolError : .toolResult,
      toolName: displayToolName(name),
      toolUseID: toolUseID,
      isError: isError
    )
  }

  static func toolDenied(name: String, reason: String?, toolUseID: String?) -> ChatMessage {
    ChatMessage(
      role: .toolDenied,
      content: reason?.isEmpty == false ? reason! : "Denied",
      messageType: .toolDenied,
      toolName: displayToolName(name),
      toolUseID: toolUseID,
      isError: true
    )
  }

  /// Renders an `update_plan` checklist as markdown checkboxes so the shared
  /// todo renderer shows real state, like the Codex plan mapping.
  static func planMarkdown(steps: [(step: String, status: String)]) -> String {
    steps.map { entry in
      let checkbox = entry.status == "completed" ? "- [x]" : "- [ ]"
      return "\(checkbox) \(entry.step.isEmpty ? "Step" : entry.step)"
    }
    .joined(separator: "\n")
  }

  static func subagentToolUse(name: String, task: String, model: String, toolUseID: String) -> ChatMessage {
    MessageFactory.toolUseMessage(
      toolName: "Task",
      input: task,
      toolInputData: ToolInputData(parameters: [
        "description": task,
        "subagent_type": name,
        "model": model,
      ]),
      toolUseID: toolUseID
    )
  }

  static func subagentToolResult(
    name: String,
    steps: Int,
    toolCalls: Int,
    costUSD: Double,
    resultPreview: String,
    toolUseID: String?
  ) -> ChatMessage {
    let summary = "\(name) · \(steps) steps · \(toolCalls) tool calls · $\(String(format: "%.4f", costUSD))"
    let trimmedPreview = resultPreview.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = trimmedPreview.isEmpty ? summary : "\(summary)\n\(trimmedPreview)"
    return ChatMessage(
      role: .toolResult,
      content: content,
      messageType: .toolResult,
      toolName: "Task",
      toolUseID: toolUseID
    )
  }

  static func stringParameters(from arguments: [String: Any]) -> [String: String] {
    var parameters: [String: String] = [:]
    for (key, value) in arguments {
      parameters[key] = stringValue(from: value)
    }
    return parameters
  }

  /// The single-line input shown on the card header, picked per tool so the
  /// most useful argument leads (the command for bash, the path for files).
  static func primaryInput(toolName: String, parameters: [String: String]) -> String {
    let preferredKeys: [String]
    switch toolName {
    case "bash": preferredKeys = ["command"]
    case "read_file", "write_file", "edit_file", "view_image": preferredKeys = ["path", "file_path"]
    case "grep": preferredKeys = ["pattern"]
    case "glob": preferredKeys = ["pattern"]
    case "task": preferredKeys = ["task"]
    case "skill": preferredKeys = ["name"]
    case "web_fetch": preferredKeys = ["url"]
    case "ask_user": preferredKeys = ["question"]
    default: preferredKeys = []
    }

    for key in preferredKeys {
      if let value = parameters[key], !value.isEmpty {
        return value
      }
    }

    return parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: "\n")
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
