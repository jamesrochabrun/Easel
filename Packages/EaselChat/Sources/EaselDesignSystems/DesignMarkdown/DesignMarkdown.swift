//
//  DesignMarkdown.swift
//  EaselDesignSystems
//

import Foundation

/// An in-memory representation of a Google `DESIGN.md` document: machine-readable
/// front-matter tokens plus ordered, human-readable prose sections.
///
/// Token containers are ordered arrays (not dictionaries) because token order is
/// meaningful for display and for the linter's section/summary output, and the
/// parser preserves the order keys appear in the source.
public struct DesignMarkdown: Equatable, Sendable {
  public var version: String?
  public var name: String
  /// The spec's `description` field (renamed to avoid colliding with
  /// `CustomStringConvertible.description`).
  public var detail: String?
  public var colors: [ColorToken]
  public var typography: [TypographyToken]
  public var rounded: [DimensionToken]
  public var spacing: [DimensionToken]
  public var components: [ComponentToken]
  /// Unknown top-level front-matter keys, preserved for the `unknown-key` lint
  /// rule and lossless round-tripping.
  public var unknownFrontMatterKeys: [String]
  public var sections: [DesignSection]

  public init(
    version: String? = nil,
    name: String,
    detail: String? = nil,
    colors: [ColorToken] = [],
    typography: [TypographyToken] = [],
    rounded: [DimensionToken] = [],
    spacing: [DimensionToken] = [],
    components: [ComponentToken] = [],
    unknownFrontMatterKeys: [String] = [],
    sections: [DesignSection] = []
  ) {
    self.version = version
    self.name = name
    self.detail = detail
    self.colors = colors
    self.typography = typography
    self.rounded = rounded
    self.spacing = spacing
    self.components = components
    self.unknownFrontMatterKeys = unknownFrontMatterKeys
    self.sections = sections
  }
}

extension DesignMarkdown {
  public struct ColorToken: Equatable, Sendable {
    public var name: String
    /// A CSS color literal (`#1A1C1E`, `oklch(...)`, named) or a raw reference.
    public var value: String

    public init(name: String, value: String) {
      self.name = name
      self.value = value
    }
  }

  public struct TypographyToken: Equatable, Sendable {
    public var name: String
    public var fontFamily: String?
    public var fontSize: String?
    public var fontWeight: String?
    public var lineHeight: String?
    public var letterSpacing: String?
    public var fontFeature: String?
    public var fontVariation: String?
    /// Unknown sub-keys, preserved for round-tripping and `unknown-key` lint.
    public var unknownKeys: [String]

    public init(
      name: String,
      fontFamily: String? = nil,
      fontSize: String? = nil,
      fontWeight: String? = nil,
      lineHeight: String? = nil,
      letterSpacing: String? = nil,
      fontFeature: String? = nil,
      fontVariation: String? = nil,
      unknownKeys: [String] = []
    ) {
      self.name = name
      self.fontFamily = fontFamily
      self.fontSize = fontSize
      self.fontWeight = fontWeight
      self.lineHeight = lineHeight
      self.letterSpacing = letterSpacing
      self.fontFeature = fontFeature
      self.fontVariation = fontVariation
      self.unknownKeys = unknownKeys
    }
  }

  /// A `rounded` / `spacing` scale entry (scale level → dimension).
  public struct DimensionToken: Equatable, Sendable {
    public var name: String
    /// `"8px"`, `"0.5rem"`, or a bare number string.
    public var value: String

    public init(name: String, value: String) {
      self.name = name
      self.value = value
    }
  }

  public struct ComponentToken: Equatable, Sendable {
    public var name: String
    public var properties: [ComponentProperty]

    public init(name: String, properties: [ComponentProperty]) {
      self.name = name
      self.properties = properties
    }
  }

  public struct ComponentProperty: Equatable, Sendable {
    public var key: String
    public var value: DesignTokenValue

    public init(key: String, value: DesignTokenValue) {
      self.key = key
      self.value = value
    }
  }
}

/// A prose section of a `DESIGN.md` body.
public struct DesignSection: Equatable, Sendable {
  /// The canonical kind, or `nil` when the heading is unrecognized.
  public var kind: DesignSectionKind?
  /// The heading text exactly as authored (e.g. `"Colors"` or `"Brand & Style"`).
  public var title: String
  /// The markdown body following the `##` heading (heading line excluded).
  public var body: String

  public init(kind: DesignSectionKind?, title: String, body: String) {
    self.kind = kind
    self.title = title
    self.body = body
  }
}

// MARK: - Token-reference resolution

extension DesignMarkdown {
  /// Resolves a token reference to its literal value, following reference chains
  /// (with a depth guard against cycles). Returns `nil` for a broken reference.
  public func resolvedLiteral(for reference: TokenReference, depth: Int = 0) -> String? {
    guard depth < 16, let category = reference.category else { return nil }
    let key = reference.path.count > 1 ? reference.path[1] : nil

    switch category {
    case "colors":
      guard let key, let token = colors.first(where: { $0.name == key }) else { return nil }
      return resolveChained(token.value, depth: depth)
    case "rounded":
      guard let key, let token = rounded.first(where: { $0.name == key }) else { return nil }
      return resolveChained(token.value, depth: depth)
    case "spacing":
      guard let key, let token = spacing.first(where: { $0.name == key }) else { return nil }
      return resolveChained(token.value, depth: depth)
    case "typography":
      // A typography reference points at a named style group; existence is what
      // matters, so resolve to the token name as a non-nil sentinel.
      guard let key, typography.contains(where: { $0.name == key }) else { return nil }
      return key
    case "components":
      guard let key, components.contains(where: { $0.name == key }) else { return nil }
      return key
    default:
      return nil
    }
  }

  /// `true` when the reference resolves to an existing token.
  public func canResolve(_ reference: TokenReference) -> Bool {
    resolvedLiteral(for: reference) != nil
  }

  private func resolveChained(_ raw: String, depth: Int) -> String? {
    if let nested = TokenReference(raw: raw) {
      return resolvedLiteral(for: nested, depth: depth + 1)
    }
    return raw
  }
}
