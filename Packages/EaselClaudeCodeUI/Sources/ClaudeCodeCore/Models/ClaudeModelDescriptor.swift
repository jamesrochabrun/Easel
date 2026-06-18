//
//  ClaudeModelDescriptor.swift
//  ClaudeCodeUI
//

import Foundation

public struct ClaudeModelDescriptor: Identifiable, Hashable, Sendable {
  public let identifier: String
  public let displayName: String
  public let detail: String?

  public var id: String { identifier }

  public init(
    identifier: String,
    displayName: String,
    detail: String? = nil
  ) {
    self.identifier = identifier
    self.displayName = displayName
    self.detail = detail
  }
}
