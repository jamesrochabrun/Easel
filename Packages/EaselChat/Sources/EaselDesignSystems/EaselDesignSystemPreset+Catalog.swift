//
//  EaselDesignSystemPreset+Catalog.swift
//  EaselChat
//

import Foundation

extension EaselDesignSystemPreset {
  public var catalog: EaselDesignSystemCatalog {
    EaselDesignSystemCatalog(
      name: displayName,
      summary: "No reusable design system is selected for this project.",
      generatedAt: nil,
      componentGroups: []
    )
  }
}
