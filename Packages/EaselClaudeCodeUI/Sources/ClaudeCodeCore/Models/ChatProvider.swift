//
//  ChatProvider.swift
//  ClaudeCodeUI
//

import Foundation

public enum ChatProvider: String, CaseIterable, Codable, Identifiable, Sendable {
  case claude
  case codex

  public static var allCases: [ChatProvider] {
    [.codex]
  }

  public var supportedProvider: ChatProvider {
    switch self {
    case .claude:
      return .codex
    case .codex:
      return .codex
    }
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
