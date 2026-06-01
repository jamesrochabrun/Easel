//
//  EaselDesignSystemCatalog.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemCatalog: Codable, Equatable, Sendable {
  public let name: String
  public let summary: String
  public let generatedAt: Date?
  public let componentGroups: [EaselDesignSystemComponentGroup]

  public init(
    name: String,
    summary: String,
    generatedAt: Date?,
    componentGroups: [EaselDesignSystemComponentGroup]
  ) {
    self.name = name
    self.summary = summary
    self.generatedAt = generatedAt
    self.componentGroups = componentGroups
  }

  public static func placeholder(for profile: EaselDesignSystemProfile) -> EaselDesignSystemCatalog {
    EaselDesignSystemCatalog(
      name: profile.name,
      summary: "The generated catalog will appear after Codex finishes creating this design system.",
      generatedAt: nil,
      componentGroups: []
    )
  }
}
