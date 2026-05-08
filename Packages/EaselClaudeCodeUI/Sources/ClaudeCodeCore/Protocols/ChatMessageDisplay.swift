//
//  ChatMessageDisplay.swift
//  ClaudeCodeUI
//

import Foundation

@MainActor
protocol ChatMessageDisplay: AnyObject {
  func addMessage(_ message: ChatMessage)
  func updateMessage(id: UUID, content: String, isComplete: Bool, isError: Bool)
  func removeMessage(id: UUID)
  func loadMessages(_ newMessages: [ChatMessage])
  func getAllMessages() -> [ChatMessage]
}

extension MessageStore: ChatMessageDisplay {}
