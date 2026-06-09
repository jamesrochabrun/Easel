//
//  DesignMarkdownGenerating.swift
//  EaselDesignSystems
//

import Foundation

/// Produces spec-compliant `DESIGN.md` text from a natural-language prompt.
///
/// This is the pure seam for the prompt-based creation path: the concrete,
/// model-backed implementation lives in `EaselChat` (so the design-system
/// package stays free of any LLM-SDK dependency and remains easy to stub in
/// tests).
public protocol DesignMarkdownGenerating: Sendable {
  /// - Parameters:
  ///   - prompt: A description of the desired brand / design system.
  ///   - name: An optional suggested name; the implementation should fall back
  ///     to a name derived from the prompt when `nil`.
  /// - Returns: Raw `DESIGN.md` text (YAML front matter + markdown body). The
  ///   caller parses, lints, and re-emits it canonically.
  func generateDesignMarkdown(prompt: String, name: String?) async throws -> String
}

/// The authoring rules embedded into the generation prompt so output conforms to
/// the Google `DESIGN.md` spec. Shared so the prompt and tests stay in sync.
public enum DesignMarkdownSpecGuide {
  public static let rules = """
  Produce a single DESIGN.md file describing a visual identity for coding agents.

  STRUCTURE
  - Start with YAML front matter delimited by `---` fences, then a markdown body.
  - Front-matter keys, in this order: version (use "alpha"), name, description \
  (optional), colors, typography, rounded, spacing, components.
  - colors: map semantic names (primary, secondary, tertiary, neutral, plus \
  accents) to CSS colors. Always quote color values, e.g. primary: "#1A1C1E".
  - typography: 9–15 named levels (e.g. display-lg, headline-md, body-md, \
  label-sm). Each is a map with fontFamily, fontSize, fontWeight, lineHeight, \
  and optionally letterSpacing.
  - rounded and spacing: scale levels (sm, md, lg, …) to dimensions like 8px.
  - components: component names (e.g. button-primary) to properties drawn ONLY \
  from: backgroundColor, textColor, typography, rounded, padding, size, height, \
  width. Reference tokens with curly braces, quoted: backgroundColor: \
  "{colors.primary}". Express states as separate entries (button-primary-hover).

  PROSE BODY (## headings, in this exact order, omit a section only if empty):
  Overview, Colors, Typography, Layout, Elevation & Depth, Shapes, Components, \
  Do's and Don'ts. Tokens are normative; prose explains WHY and HOW to apply them.

  QUALITY
  - Always define a `primary` color.
  - Keep text/background pairs at WCAG AA contrast (≥ 4.5:1 for body text).
  - Every token reference must resolve to a defined token.

  Output ONLY the DESIGN.md content — no code fences, no commentary.
  """
}
