//
//  ChatProvider.swift
//  ClaudeCodeUI
//

import Foundation

public enum ChatProvider: String, CaseIterable, Codable, Identifiable, Sendable {
  case claude
  case codex
  /// The Arnes CLI harness over OpenRouter: any OpenRouter model (or
  /// `openrouter/auto` routing) driving the same local agent loop. The model
  /// is selected inline from the chat composer.
  case arnes
  /// Raw LLM APIs driven by the in-app agentic harness: local model servers
  /// (Ollama, LM Studio, llama.cpp), on-device MLX, and hosted
  /// OpenAI-compatible endpoints. Configured via endpoint profiles.
  case api

  public static var allCases: [ChatProvider] {
    [.codex, .claude, .arnes, .api]
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
    case .arnes:
      return "OpenRouter"
    case .api:
      return "Local / API"
    }
  }

  /// Unknown raw values (e.g. data written by a newer app version) fall back
  /// to the default provider instead of failing the decode of the session or
  /// preferences that contain them.
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ChatProvider(rawValue: raw) ?? .codex
  }
}
