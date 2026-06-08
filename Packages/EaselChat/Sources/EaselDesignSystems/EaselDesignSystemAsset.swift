//
//  EaselDesignSystemAsset.swift
//  EaselChat
//

import Foundation

/// A raster asset extracted from a `.fig` source (logo, photo, icon image, or
/// the document thumbnail), copied into the design system folder. `relativePath`
/// is relative to the design system root so it resolves both in `index.html`
/// (served from the root) and natively (joined onto the working directory).
public struct EaselDesignSystemAsset: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let relativePath: String
  public let kind: String

  public init(
    id: String,
    name: String,
    relativePath: String,
    kind: String
  ) {
    self.id = id
    self.name = name
    self.relativePath = relativePath
    self.kind = kind
  }
}
