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
    case .overview: return ["Brand & Style"]
    case .layout: return ["Layout & Spacing"]
    case .elevation: return ["Elevation"]
    default: return []
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
    value
      .trimmingCharacters(in: .whitespaces)
      .lowercased()
      .replacingOccurrences(of: "\u{2019}", with: "'") // curly → straight apostrophe
  }
}
