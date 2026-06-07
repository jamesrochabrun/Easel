//
//  EaselDesignSystemComponentGroup.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemComponentGroup: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let previewPath: String?
  public let sourcePath: String?
  public let items: [EaselDesignSystemComponentItem]

  public init(
    id: String,
    title: String,
    summary: String,
    previewPath: String?,
    sourcePath: String? = nil,
    items: [EaselDesignSystemComponentItem]
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.previewPath = previewPath
    self.sourcePath = sourcePath
    self.items = items
  }
}
