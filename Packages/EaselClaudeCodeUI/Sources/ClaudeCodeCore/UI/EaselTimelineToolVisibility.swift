//
//  EaselTimelineToolVisibility.swift
//  ClaudeCodeUI
//

enum EaselTimelineToolVisibility {
  static func shouldHideToolPair(toolUse: ChatMessage, toolResult: ChatMessage?) -> Bool {
    guard let toolResult else { return false }
    return shouldHideToolResult(toolResult)
  }

  static func shouldHideToolResult(_ message: ChatMessage) -> Bool {
    message.messageType == .toolError
  }
}
