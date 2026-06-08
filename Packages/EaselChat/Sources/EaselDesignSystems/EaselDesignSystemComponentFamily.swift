//
//  EaselDesignSystemComponentFamily.swift
//  EaselChat
//

import Foundation

/// A grouped component family parsed from a `.fig` source, richer than
/// `EaselDesignSystemComponentGroup`: it carries the source page, variant count,
/// the variant property names/values discovered in the kit, and an optional
/// local preview path.
public struct EaselDesignSystemComponentFamily: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let category: String
  public let summary: String
  public let sourcePage: String?
  public let variantCount: Int
  public let variantProperties: [EaselDesignSystemVariantProperty]
  public let preview: EaselDesignSystemPreviewScene?
  public let confidence: Double

  public init(
    id: String,
    title: String,
    category: String,
    summary: String,
    sourcePage: String?,
    variantCount: Int,
    variantProperties: [EaselDesignSystemVariantProperty],
    preview: EaselDesignSystemPreviewScene? = nil,
    confidence: Double
  ) {
    self.id = id
    self.title = title
    self.category = category
    self.summary = summary
    self.sourcePage = sourcePage
    self.variantCount = variantCount
    self.variantProperties = variantProperties
    self.preview = preview
    self.confidence = confidence
  }
}

/// A single Figma variant property (e.g. `Kind`) and the distinct values
/// discovered for it across a family (e.g. `filled`, `outlined`).
public struct EaselDesignSystemVariantProperty: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let values: [String]

  public init(id: String, name: String, values: [String]) {
    self.id = id
    self.name = name
    self.values = values
  }
}
