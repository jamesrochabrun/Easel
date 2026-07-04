//
//  WebPreviewTokenPromotionOffer.swift
//  EaselWebInspector
//
//  A just-written style edit that detached from a shared design token, and
//  everything needed to instead promote it into a token-wide update: restore
//  the element's `var(token)` reference and rewrite the token's definition.
//

import Foundation

public struct WebPreviewTokenPromotionOffer: Equatable, Sendable {
  /// CSS property whose declaration detached (e.g. "background-color").
  public let property: String
  /// The design token that was detached from (e.g. "--secondary").
  public let token: String
  /// `var(token)` usages across the project's stylesheets.
  public let usageCount: Int
  /// The literal value the detached write put on disk.
  public let appliedLiteral: String
  /// Rule index path of the token's definition in the same source.
  public let definitionRuleIndexPath: [Int]

  public init(
    property: String,
    token: String,
    usageCount: Int,
    appliedLiteral: String,
    definitionRuleIndexPath: [Int]
  ) {
    self.property = property
    self.token = token
    self.usageCount = usageCount
    self.appliedLiteral = appliedLiteral
    self.definitionRuleIndexPath = definitionRuleIndexPath
  }

  /// "Update --secondary everywhere (12 uses)"
  public var actionLabel: String {
    let uses = usageCount == 1 ? "1 use" : "\(usageCount) uses"
    return "Update \(token) everywhere (\(uses))"
  }

  /// "Changed this element only · detached from --secondary"
  public var contextLabel: String {
    "Changed this element only · detached from \(token)"
  }
}
