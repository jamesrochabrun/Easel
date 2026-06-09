//
//  TokenReference.swift
//  EaselDesignSystems
//

import Foundation

/// A value in a `DESIGN.md` token tree: either a literal (e.g. `"#1A1C1E"`,
/// `"12px"`) or a reference to another token (e.g. `"{colors.primary}"`).
public enum DesignTokenValue: Equatable, Sendable {
  case literal(String)
  case reference(TokenReference)

  /// Parses a raw YAML scalar into a token value. A value wrapped in a single
  /// pair of curly braces with a dotted path is treated as a reference;
  /// everything else is a literal.
  public init(raw: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    if let reference = TokenReference(raw: trimmed) {
      self = .reference(reference)
    } else {
      self = .literal(trimmed)
    }
  }

  /// The raw string form for serialization (references re-wrapped in braces).
  public var rawString: String {
    switch self {
    case .literal(let value): return value
    case .reference(let reference): return reference.rawString
    }
  }
}

/// A `{category.path}` reference into a `DESIGN.md` front-matter token tree,
/// e.g. `{colors.primary}` or `{typography.label-md}`.
public struct TokenReference: Equatable, Sendable {
  public let path: [String]

  public init(path: [String]) {
    self.path = path
  }

  /// Parses `"{colors.primary}"`. Returns `nil` when the string is not a single
  /// brace-wrapped dotted path (so YAML flow maps like `{a: b}` are rejected).
  public init?(raw: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}"), trimmed.count >= 3 else {
      return nil
    }
    let inner = String(trimmed.dropFirst().dropLast())
      .trimmingCharacters(in: .whitespaces)
    // References are dotted paths; reject anything resembling a flow collection.
    guard !inner.isEmpty,
          !inner.contains(":"),
          !inner.contains("{"),
          !inner.contains("}"),
          !inner.contains(",") else {
      return nil
    }
    let components = inner.split(separator: ".").map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard components.count >= 2, components.allSatisfy({ !$0.isEmpty }) else {
      return nil
    }
    self.path = components
  }

  public var category: String? { path.first }

  public var rawString: String { "{\(path.joined(separator: "."))}" }
}
