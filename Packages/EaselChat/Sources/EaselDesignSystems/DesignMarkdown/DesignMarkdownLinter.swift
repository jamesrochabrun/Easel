//
//  DesignMarkdownLinter.swift
//  EaselDesignSystems
//

import Foundation

/// A single linter finding against a ``DesignMarkdown`` document.
public struct DesignMarkdownLintFinding: Equatable, Sendable {
  public enum Severity: String, Sendable, Comparable {
    case info
    case warning
    case error

    private var rank: Int {
      switch self {
      case .info: return 0
      case .warning: return 1
      case .error: return 2
      }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rank < rhs.rank }
  }

  /// The rule identifier, matching the `@google/design.md` rule names.
  public let rule: String
  public let severity: Severity
  public let message: String
  /// A token/section path (e.g. `components.button-primary`) when applicable.
  public let location: String?

  public init(rule: String, severity: Severity, message: String, location: String? = nil) {
    self.rule = rule
    self.severity = severity
    self.message = message
    self.location = location
  }
}

/// Thrown by ``DesignMarkdownLinter/validate(_:)`` when a document has any
/// blocking (`.error`) finding.
public struct DesignMarkdownLintError: LocalizedError, Equatable, Sendable {
  public let findings: [DesignMarkdownLintFinding]

  public var errorDescription: String? {
    let messages = findings.filter { $0.severity == .error }.map(\.message)
    return "DESIGN.md failed validation: " + messages.joined(separator: "; ")
  }
}

/// A Swift port of the high-value `@google/design.md` lint rules. Per product
/// decision, only `broken-ref` is blocking; everything else is advisory.
public enum DesignMarkdownLinter {

  public static func lint(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    var findings: [DesignMarkdownLintFinding] = []
    findings += brokenReferences(document)
    findings += missingPrimary(document)
    findings += contrastIssues(document)
    findings += sectionOrderIssues(document)
    findings += missingTypography(document)
    findings += unknownKeys(document)
    return findings
  }

  /// Throws ``DesignMarkdownLintError`` if any `.error` finding is present.
  public static func validate(_ document: DesignMarkdown) throws {
    let findings = lint(document)
    if findings.contains(where: { $0.severity == .error }) {
      throw DesignMarkdownLintError(findings: findings)
    }
  }

  // MARK: - Rules

  private static func brokenReferences(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    var findings: [DesignMarkdownLintFinding] = []
    for (reference, location) in references(in: document) where !document.canResolve(reference) {
      findings.append(.init(
        rule: "broken-ref",
        severity: .error,
        message: "Token reference \(reference.rawString) does not resolve.",
        location: location
      ))
    }
    return findings
  }

  private static func missingPrimary(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    guard !document.colors.isEmpty,
          !document.colors.contains(where: { $0.name == "primary" }) else {
      return []
    }
    return [.init(
      rule: "missing-primary",
      severity: .warning,
      message: "No `primary` color is defined. A primary color anchors the palette.",
      location: "colors"
    )]
  }

  private static func contrastIssues(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    var findings: [DesignMarkdownLintFinding] = []
    for component in document.components {
      guard let background = colorString(forKey: "backgroundColor", in: component, document: document),
            let text = colorString(forKey: "textColor", in: component, document: document),
            let ratio = WCAGContrast.contrastRatio(background, text) else {
        continue
      }
      if ratio < WCAGContrast.aaNormalText {
        let formatted = String(format: "%.2f", ratio)
        findings.append(.init(
          rule: "contrast-ratio",
          severity: .warning,
          message: "Text/background contrast is \(formatted):1, below WCAG AA (4.5:1).",
          location: "components.\(component.name)"
        ))
      }
    }
    return findings
  }

  private static func sectionOrderIssues(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    var findings: [DesignMarkdownLintFinding] = []
    var previous = -1
    for section in document.sections {
      guard let kind = section.kind else { continue }
      if kind.rawValue < previous {
        findings.append(.init(
          rule: "section-order",
          severity: .warning,
          message: "Section \"\(section.title)\" is out of canonical order.",
          location: section.title
        ))
      }
      previous = kind.rawValue
    }
    return findings
  }

  private static func missingTypography(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    guard !document.colors.isEmpty, document.typography.isEmpty else { return [] }
    return [.init(
      rule: "missing-typography",
      severity: .warning,
      message: "Colors are defined but no typography tokens are present.",
      location: "typography"
    )]
  }

  private static func unknownKeys(_ document: DesignMarkdown) -> [DesignMarkdownLintFinding] {
    var findings: [DesignMarkdownLintFinding] = []
    for key in document.unknownFrontMatterKeys {
      findings.append(.init(
        rule: "unknown-key",
        severity: .warning,
        message: "Unknown front-matter key \"\(key)\".",
        location: key
      ))
    }
    // Collapse extended-schema properties into a single concise heads-up rather
    // than one warning per property, so a richer dialect doesn't flood the panel.
    let unknownTypographyKeys = distinct(document.typography.flatMap(\.unknownKeys))
    if !unknownTypographyKeys.isEmpty {
      findings.append(.init(
        rule: "unknown-key",
        severity: .warning,
        message: "Typography properties outside the DESIGN.md spec (ignored by spec consumers): \(list(unknownTypographyKeys)).",
        location: "typography"
      ))
    }
    // Component properties are intentionally free-form: real-world DESIGN.md
    // dialects carry rich styling keys (borderColor, cellPadding, …) that aren't
    // in the spec's core set but are perfectly valid. We accept and round-trip
    // them silently rather than nagging — only top-level and typography keys,
    // where a stray key is more likely a genuine typo, are flagged above.
    return findings
  }

  /// Distinct values preserving first-seen order.
  private static func distinct(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }

  /// A comma-joined list, capped so the message stays a single readable line.
  private static func list(_ values: [String], limit: Int = 12) -> String {
    let shown = values.prefix(limit).joined(separator: ", ")
    return values.count > limit ? "\(shown), +\(values.count - limit) more" : shown
  }

  // MARK: - Helpers

  private static func references(in document: DesignMarkdown) -> [(TokenReference, String)] {
    var result: [(TokenReference, String)] = []
    for color in document.colors {
      if case .reference(let reference) = DesignTokenValue(raw: color.value) {
        result.append((reference, "colors.\(color.name)"))
      }
    }
    for component in document.components {
      for property in component.properties {
        if case .reference(let reference) = property.value {
          result.append((reference, "components.\(component.name).\(property.key)"))
        }
      }
    }
    return result
  }

  private static func colorString(
    forKey key: String,
    in component: DesignMarkdown.ComponentToken,
    document: DesignMarkdown
  ) -> String? {
    guard let property = component.properties.first(where: { $0.key == key }) else { return nil }
    switch property.value {
    case .literal(let value): return value
    case .reference(let reference): return document.resolvedLiteral(for: reference)
    }
  }
}
