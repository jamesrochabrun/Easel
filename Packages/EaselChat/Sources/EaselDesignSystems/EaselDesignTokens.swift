//
//  EaselDesignTokens.swift
//  EaselDesignSystems
//
//  Low-level design-token primitives for the schemaVersion 3 catalog.
//  These carry the *actual values* (hex colors, type metrics, spacing,
//  shadows, etc.) so the app-owned `index.html` can render a faithful,
//  token-driven design system instead of placeholder specimens.
//

import Foundation

/// A single color primitive. `value` is a CSS color (hex preferred);
/// `onColor` is the readable foreground to place on top of it.
public struct EaselDesignColorToken: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  /// Optional grouping label, e.g. "Brand", "Neutral", "Semantic", "Surface".
  public let group: String?
  public let value: String
  public let onColor: String?
  public let description: String?

  public init(
    id: String? = nil,
    name: String,
    group: String? = nil,
    value: String,
    onColor: String? = nil,
    description: String? = nil
  ) {
    self.id = id
    self.name = name
    self.group = group
    self.value = value
    self.onColor = onColor
    self.description = description
  }
}

/// A font family available to the type scale.
public struct EaselDesignFontToken: Codable, Equatable, Sendable {
  /// Logical role referenced by `EaselDesignTypeStyle.fontRole`, e.g. "Sans", "Mono".
  public let role: String?
  public let family: String
  /// Full CSS font stack including fallbacks.
  public let stack: String?
  /// Optional web-font stylesheet URL (e.g. Google Fonts) to load the family.
  public let link: String?

  public init(
    role: String? = nil,
    family: String,
    stack: String? = nil,
    link: String? = nil
  ) {
    self.role = role
    self.family = family
    self.stack = stack
    self.link = link
  }
}

/// A single type-scale entry, rendered at its real metrics in the catalog.
public struct EaselDesignTypeStyle: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  /// Matches an `EaselDesignFontToken.role`.
  public let fontRole: String?
  /// Font size in px.
  public let size: Double?
  /// Numeric weight, e.g. 400, 600, 700.
  public let weight: Int?
  /// Unitless line-height multiplier, e.g. 1.2.
  public let lineHeight: Double?
  /// CSS letter-spacing, e.g. "-0.02em".
  public let letterSpacing: String?
  public let sample: String?
  public let usage: String?

  public init(
    id: String? = nil,
    name: String,
    fontRole: String? = nil,
    size: Double? = nil,
    weight: Int? = nil,
    lineHeight: Double? = nil,
    letterSpacing: String? = nil,
    sample: String? = nil,
    usage: String? = nil
  ) {
    self.id = id
    self.name = name
    self.fontRole = fontRole
    self.size = size
    self.weight = weight
    self.lineHeight = lineHeight
    self.letterSpacing = letterSpacing
    self.sample = sample
    self.usage = usage
  }
}

/// Typography container: font families plus the type scale.
public struct EaselDesignTypography: Codable, Equatable, Sendable {
  public let fonts: [EaselDesignFontToken]
  public let styles: [EaselDesignTypeStyle]

  public init(
    fonts: [EaselDesignFontToken] = [],
    styles: [EaselDesignTypeStyle] = []
  ) {
    self.fonts = fonts
    self.styles = styles
  }

  enum CodingKeys: String, CodingKey {
    case fonts
    case styles
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    fonts = try container.decodeIfPresent([EaselDesignFontToken].self, forKey: .fonts) ?? []
    styles = try container.decodeIfPresent([EaselDesignTypeStyle].self, forKey: .styles) ?? []
  }
}

/// A numeric scale token used for both spacing and corner-radius scales.
/// `value` is in px.
public struct EaselDesignScaleToken: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  public let value: Double
  public let description: String?

  public init(
    id: String? = nil,
    name: String,
    value: Double,
    description: String? = nil
  ) {
    self.id = id
    self.name = name
    self.value = value
    self.description = description
  }
}

/// An elevation level. `shadow` is a full CSS `box-shadow` string and is
/// rendered onto a real card in the catalog's elevation carousel.
public struct EaselDesignElevationToken: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  public let shadow: String
  public let usage: String?

  public init(
    id: String? = nil,
    name: String,
    shadow: String,
    usage: String? = nil
  ) {
    self.id = id
    self.name = name
    self.shadow = shadow
    self.usage = usage
  }
}

/// An interaction-state primitive (default / hover / pressed / focus / disabled)
/// described by its background, foreground, and border colors.
public struct EaselDesignStateToken: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  public let description: String?
  public let background: String?
  public let foreground: String?
  public let border: String?

  public init(
    id: String? = nil,
    name: String,
    description: String? = nil,
    background: String? = nil,
    foreground: String? = nil,
    border: String? = nil
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.background = background
    self.foreground = foreground
    self.border = border
  }
}

/// A single icon. `svg` is inline SVG markup (a `<path>` or a full `<svg>`),
/// rendered directly in the catalog's icon grid.
public struct EaselDesignIconToken: Codable, Equatable, Sendable {
  public let id: String?
  public let name: String
  public let svg: String
  public let keywords: [String]?

  public init(
    id: String? = nil,
    name: String,
    svg: String,
    keywords: [String]? = nil
  ) {
    self.id = id
    self.name = name
    self.svg = svg
    self.keywords = keywords
  }
}
