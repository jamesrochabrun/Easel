//
//  LocalAgentProvider.swift
//  ClaudeCodeUI
//

import Foundation

public enum LocalAgentProvider: String, CaseIterable, Codable, Identifiable, Sendable {
  case codex
  case claude
  case arnes

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .codex:
      return "Codex"
    case .claude:
      return "Claude"
    case .arnes:
      return "OpenRouter"
    }
  }

  public var defaultCommand: String {
    switch self {
    case .codex:
      return "codex"
    case .claude:
      return "claude"
    case .arnes:
      return "arnes"
    }
  }
}
