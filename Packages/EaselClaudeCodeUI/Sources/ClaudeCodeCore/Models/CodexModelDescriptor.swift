//
//  CodexModelDescriptor.swift
//  ClaudeCodeUI
//

import Foundation

public struct CodexModelDescriptor: Identifiable, Hashable, Sendable {
  public let slug: String
  public let displayName: String
  public let description: String?
  public let visibility: String?
  public let priority: Int?

  public var id: String { slug }

  public init(
    slug: String,
    displayName: String,
    description: String? = nil,
    visibility: String? = nil,
    priority: Int? = nil
  ) {
    self.slug = slug
    self.displayName = displayName
    self.description = description
    self.visibility = visibility
    self.priority = priority
  }
}
