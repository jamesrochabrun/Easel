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
      return "Attach source"
    case .extractCatalog:
      return "Extract tokens & components"
    }
  }

  public var detail: String {
    switch self {
    case .reference:
      return "Keep the .fig file with this design system."
    case .extractCatalog:
      return "Parse the .fig locally into colors, type, spacing, and component families."
    }
  }
}
