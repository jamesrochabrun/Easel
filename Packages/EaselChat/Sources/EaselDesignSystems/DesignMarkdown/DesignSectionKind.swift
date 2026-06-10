//
//  DesignSectionKind.swift
//  EaselDesignSystems
//

import Foundation

/// The canonical `DESIGN.md` prose sections, in spec order. All sections are
/// optional, but when present they must appear in this order.
public enum DesignSectionKind: Int, CaseIterable, Comparable, Sendable {
  case overview
  case colors
  case typography
  case layout
  case elevation
  case shapes
  case components
  case dosAndDonts

  /// The heading text the emitter writes.
  public var canonicalTitle: String {
    switch self {
    case .overview: return "Overview"
    case .colors: return "Colors"
    case .typography: return "Typography"
    case .layout: return "Layout"
    case .elevation: return "Elevation & Depth"
    case .shapes: return "Shapes"
    case .components: return "Components"
    case .dosAndDonts: return "Do's and Don'ts"
    }
  }

  /// Accepted alternate headings (in addition to `canonicalTitle`).
  public var aliases: [String] {
    switch self {
    case .overview:
      return ["Brand & Style", "Visual Theme & Atmosphere", "Theme & Atmosphere"]
    case .colors:
      return ["Color Palette", "Color Palette & Roles", "Palette"]
    case .typography:
      return ["Typography Rules", "Type", "Type System"]
    case .layout:
      return ["Layout & Spacing", "Layout Principles"]
    case .elevation:
      return ["Elevation", "Depth & Elevation", "Depth"]
    case .shapes:
      return ["Border Radius", "Radius", "Radii"]
    case .components:
      return ["Component Stylings", "Component Styling", "Component Styles"]
    case .dosAndDonts:
      return ["Dos and Donts", "Dos & Donts", "Do's & Don'ts"]
    }
  }

  /// Resolves a heading string to a section kind (alias-aware, case- and
  /// apostrophe-insensitive). Returns `nil` for unrecognized headings.
  public static func match(heading: String) -> DesignSectionKind? {
    let normalized = normalize(heading)
    return allCases.first { kind in
      ([kind.canonicalTitle] + kind.aliases).contains { normalize($0) == normalized }
    }
  }

  public static func < (lhs: DesignSectionKind, rhs: DesignSectionKind) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  private static func normalize(_ value: String) -> String {
    stripNumericPrefix(value)
      .trimmingCharacters(in: .whitespaces)
      .lowercased()
      .replacingOccurrences(of: "\u{2019}", with: "'") // curly → straight apostrophe
  }

  private static func stripNumericPrefix(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    var cursor = trimmed.startIndex
    while cursor < trimmed.endIndex, trimmed[cursor].isNumber {
      cursor = trimmed.index(after: cursor)
    }
    guard cursor > trimmed.startIndex, cursor < trimmed.endIndex, trimmed[cursor] == "." else {
      return trimmed
    }
    let afterDot = trimmed.index(after: cursor)
    guard afterDot < trimmed.endIndex, trimmed[afterDot].isWhitespace else {
      return trimmed
    }
    return String(trimmed[afterDot...]).trimmingCharacters(in: .whitespaces)
  }
}
