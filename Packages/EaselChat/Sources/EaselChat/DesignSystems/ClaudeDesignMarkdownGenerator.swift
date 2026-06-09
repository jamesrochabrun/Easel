//
//  ClaudeDesignMarkdownGenerator.swift
//  EaselChat
//

import ClaudeCodeSDK
import EaselDesignSystems
import Foundation

/// Generates spec-compliant `DESIGN.md` text via the Claude Code CLI — the same
/// client `ChatService` uses, so it relies on the system `claude` auth and needs
/// no API-key management. This is the concrete `EaselChat`-side implementation of
/// the pure ``DesignMarkdownGenerating`` seam owned by `EaselDesignSystems`.
public struct ClaudeDesignMarkdownGenerator: DesignMarkdownGenerating {
  public enum GeneratorError: LocalizedError, Sendable {
    case emptyResponse
    case unexpectedResultFormat

    public var errorDescription: String? {
      switch self {
      case .emptyResponse: return "The model returned an empty design system."
      case .unexpectedResultFormat: return "The model returned an unexpected response format."
      }
    }
  }

  private let command: String

  public init(command: String = "claude") {
    self.command = command
  }

  public func generateDesignMarkdown(prompt: String, name: String?) async throws -> String {
    var config = ChatConfiguration.makeDefault()
    config.command = command
    let client = try ClaudeCodeClient(configuration: config)

    var options = ClaudeCodeOptions()
    options.systemPrompt = DesignMarkdownSpecGuide.rules

    let namePhrase = name.map { " named \"\($0)\"" } ?? ""
    let userPrompt = """
    Create a DESIGN.md for the following brand or product\(namePhrase):

    \(prompt)
    """

    let result = try await client.runSinglePrompt(
      prompt: userPrompt,
      outputFormat: .text,
      options: options
    )

    switch result {
    case .text(let text):
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { throw GeneratorError.emptyResponse }
      return trimmed
    case .json, .stream:
      throw GeneratorError.unexpectedResultFormat
    }
  }
}
