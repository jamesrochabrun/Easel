//
//  EaselDesignSystemComponentItem.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemComponentItem: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let previewPath: String?
  public let sourcePath: String?

  public init(
    id: String,
    title: String,
    summary: String,
    previewPath: String? = nil,
    sourcePath: String? = nil
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.previewPath = previewPath
    self.sourcePath = sourcePath
  }
}
