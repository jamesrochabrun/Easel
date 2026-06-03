//
//  ProjectResourcePreview.swift
//  EaselChat
//

import Foundation

public struct ProjectResourcePreview: Equatable, Sendable {
  public enum Content: Equatable, Sendable {
    case text(String)
    case visual
    case unavailable(String)
  }

  public let itemID: String
  public let content: Content

  public init(itemID: String, content: Content) {
    self.itemID = itemID
    self.content = content
  }
}
