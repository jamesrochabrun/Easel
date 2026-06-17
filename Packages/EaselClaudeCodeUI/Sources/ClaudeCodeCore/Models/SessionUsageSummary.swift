//
//  SessionUsageSummary.swift
//  ClaudeCodeUI
//

import Foundation

public struct SessionUsageSummary: Codable, Equatable, Sendable {
  public static let zero = SessionUsageSummary()

  public var inputTokens: Int
  public var outputTokens: Int
  public var cachedInputTokens: Int
  public var reasoningOutputTokens: Int

  public init(
    inputTokens: Int = 0,
    outputTokens: Int = 0,
    cachedInputTokens: Int = 0,
    reasoningOutputTokens: Int = 0
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.cachedInputTokens = cachedInputTokens
    self.reasoningOutputTokens = reasoningOutputTokens
  }

  /// Provider-reported input plus output tokens. Cached input and reasoning
  /// output are tracked separately because provider usage events can overlap
  /// those fields.
  public var totalTokens: Int {
    inputTokens + outputTokens
  }

  public var hasUsage: Bool {
    totalTokens > 0 || cachedInputTokens > 0 || reasoningOutputTokens > 0
  }

  public mutating func add(_ record: SessionUsageRecord) {
    inputTokens += record.inputTokens
    outputTokens += record.outputTokens
    cachedInputTokens += record.cachedInputTokens
    reasoningOutputTokens += record.reasoningOutputTokens
  }

  public func adding(_ record: SessionUsageRecord) -> SessionUsageSummary {
    var summary = self
    summary.add(record)
    return summary
  }

  public func adding(_ other: SessionUsageSummary) -> SessionUsageSummary {
    SessionUsageSummary(
      inputTokens: inputTokens + other.inputTokens,
      outputTokens: outputTokens + other.outputTokens,
      cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
      reasoningOutputTokens: reasoningOutputTokens + other.reasoningOutputTokens
    )
  }

  public static func formattedTokenCount(_ count: Int) -> String {
    NumberFormatter.localizedString(from: NSNumber(value: max(0, count)), number: .decimal)
  }

  public var formattedTotalTokens: String {
    "\(Self.formattedTokenCount(totalTokens)) API tokens"
  }

  public var formattedBreakdown: String {
    var parts = [
      "\(Self.formattedTokenCount(inputTokens)) input",
      "\(Self.formattedTokenCount(outputTokens)) output"
    ]
    if cachedInputTokens > 0 {
      parts.append("\(Self.formattedTokenCount(cachedInputTokens)) cached input")
    }
    if reasoningOutputTokens > 0 {
      parts.append("\(Self.formattedTokenCount(reasoningOutputTokens)) reasoning output")
    }
    return parts.joined(separator: ", ")
  }

  private enum CodingKeys: String, CodingKey {
    case inputTokens
    case outputTokens
    case cachedInputTokens
    case reasoningOutputTokens
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
    outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
    cachedInputTokens = try container.decodeIfPresent(Int.self, forKey: .cachedInputTokens) ?? 0
    reasoningOutputTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningOutputTokens) ?? 0
  }
}
