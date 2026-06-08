//
//  EaselDesignSystemFigImportMode.swift
//  EaselChat
//

import Foundation

public enum EaselDesignSystemFigImportMode: String, CaseIterable, Codable, Identifiable, Sendable {
  case reference
  case extractCatalog

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .reference:
      return "Reference"
    case .extractCatalog:
      return "Extract tokens & components"
    }
  }

  public var detail: String {
    switch self {
    case .reference:
      return "Keep the .fig file as local inspiration without treating it as a strict component library."
    case .extractCatalog:
      return "Parse the .fig locally into a visual reference of colors, type, and component families. Use as reference — not a 1:1 import."
    }
  }
}
