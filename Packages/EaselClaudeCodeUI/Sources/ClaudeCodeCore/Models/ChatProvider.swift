//
//  ChatProvider.swift
//  ClaudeCodeUI
//

import Foundation

public enum ChatProvider: String, CaseIterable, Codable, Identifiable, Sendable {
  case claude
  case codex

  public static var allCases: [ChatProvider] {
    [.codex, .claude]
  }

  public var supportedProvider: ChatProvider {
    self
  }

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .claude:
      return "Claude"
    case .codex:
      return "Codex"
    }
  }
}
