//
//  ChatRuntime.swift
//  ClaudeCodeUI
//

import Foundation

@MainActor
protocol ChatRuntime: AnyObject {
  var provider: ChatProvider { get }
  var workingDirectory: String? { get set }
  var activeSessionId: String? { get }

  func markSessionRestored()
  func resetSession()
  func cancel()
  func send(prompt: String, messageId: UUID, firstMessageInSession: String?) async throws
}
