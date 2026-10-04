//
//  ArnesModelDescriptor.swift
//  ClaudeCodeUI
//

import Foundation

/// One OpenRouter model as the Arnes CLI's manifest describes it.
public struct ArnesModelDescriptor: Identifiable, Hashable, Sendable {
  /// The OpenRouter slug (`anthropic/claude-sonnet-4.5`), or
  /// `openrouter/auto` for provider-side routing.
  public let identifier: String
  public let displayName: String
  /// Short capability/pricing summary shown under the name in pickers.
  public let detail: String?
  public let contextLength: Int?
  public let supportsTools: Bool
  public let supportsReasoning: Bool
  public let supportsVision: Bool
  /// USD per input token (as reported by the manifest; 0 for free models).
  public let promptPricePerToken: Double?
  /// USD per output token.
  public let completionPricePerToken: Double?

  public var id: String { identifier }

  public init(
    identifier: String,
    displayName: String,
    detail: String? = nil,
    contextLength: Int? = nil,
    supportsTools: Bool = true,
    supportsReasoning: Bool = false,
    supportsVision: Bool = false,
    promptPricePerToken: Double? = nil,
    completionPricePerToken: Double? = nil
  ) {
    self.identifier = identifier
    self.displayName = displayName
    self.detail = detail
    self.contextLength = contextLength
    self.supportsTools = supportsTools
    self.supportsReasoning = supportsReasoning
    self.supportsVision = supportsVision
    self.promptPricePerToken = promptPricePerToken
    self.completionPricePerToken = completionPricePerToken
  }

  /// The provider-side router — Arnes's default model on OpenRouter.
  public static let autoIdentifier = "openrouter/auto"

  public static let auto = ArnesModelDescriptor(
    identifier: autoIdentifier,
    displayName: "Auto",
    detail: "OpenRouter picks the best model for each request"
  )

  /// Whether this descriptor is the auto-routing pseudo-model.
  public var isAuto: Bool {
    identifier == Self.autoIdentifier
  }
}
