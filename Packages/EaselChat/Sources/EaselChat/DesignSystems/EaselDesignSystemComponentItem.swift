//
//  EaselDesignSystemComponentItem.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemComponentItem: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String

  public init(id: String, title: String, summary: String) {
    self.id = id
    self.title = title
    self.summary = summary
  }
}
