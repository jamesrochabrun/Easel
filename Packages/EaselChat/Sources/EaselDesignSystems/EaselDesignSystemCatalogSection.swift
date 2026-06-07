//
//  EaselDesignSystemCatalogSection.swift
//  EaselDesignSystems
//

import Foundation

public struct EaselDesignSystemCatalogSection: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let groups: [EaselDesignSystemComponentGroup]

  public init(
    id: String,
    title: String,
    summary: String,
    groups: [EaselDesignSystemComponentGroup]
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.groups = groups
  }
}
