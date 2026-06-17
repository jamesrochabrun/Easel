//
//  SessionUsageRecord.swift
//  ClaudeCodeUI
//

import Foundation

public struct SessionUsageRecord: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let provider: ChatProvider
  public let modelIdentifier: String?
  public let inputTokens: Int
  public let outputTokens: Int
  public let cachedInputTokens: Int
  public let reasoningOutputTokens: Int
  public let recordedAt: Date

  public init(
    id: UUID = UUID(),
    provider: ChatProvider,
    modelIdentifier: String?,
    inputTokens: Int,
    outputTokens: Int,
    cachedInputTokens: Int = 0,
    reasoningOutputTokens: Int = 0,
    recordedAt: Date = Date()
  ) {
    self.id = id
    self.provider = provider
    self.modelIdentifier = modelIdentifier
    self.inputTokens = max(0, inputTokens)
    self.outputTokens = max(0, outputTokens)
    self.cachedInputTokens = max(0, min(cachedInputTokens, inputTokens))
    self.reasoningOutputTokens = max(0, reasoningOutputTokens)
    self.recordedAt = recordedAt
  }

  public var hasUsage: Bool {
    inputTokens > 0 || outputTokens > 0 || cachedInputTokens > 0 || reasoningOutputTokens > 0
  }
}
