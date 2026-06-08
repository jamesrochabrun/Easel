//
//  EaselDesignSystemSourceDiagnostics.swift
//  EaselChat
//

import Foundation

/// Honest reporting about how the `.fig` source(s) were parsed, surfaced so the
/// catalog never silently overstates fidelity. Includes parse counts, node
/// totals, parser identity, and free-form warnings about noisy extraction.
public struct EaselDesignSystemSourceDiagnostics: Codable, Equatable, Sendable {
  public let parsedCount: Int
  public let failedCount: Int
  public let skippedCount: Int
  public let totalNodeCount: Int
  public let parserName: String?
  public let parserVersion: String?
  public let warnings: [String]

  public init(
    parsedCount: Int,
    failedCount: Int,
    skippedCount: Int,
    totalNodeCount: Int,
    parserName: String?,
    parserVersion: String?,
    warnings: [String]
  ) {
    self.parsedCount = parsedCount
    self.failedCount = failedCount
    self.skippedCount = skippedCount
    self.totalNodeCount = totalNodeCount
    self.parserName = parserName
    self.parserVersion = parserVersion
    self.warnings = warnings
  }
}
