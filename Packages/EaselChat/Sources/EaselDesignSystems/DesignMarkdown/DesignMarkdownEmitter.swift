//
//  DesignMarkdownEmitter.swift
//  EaselDesignSystems
//

import Foundation

/// Serializes a ``DesignMarkdown`` into spec-compliant `DESIGN.md` text and
/// builds a ``DesignMarkdown`` from a Figma-derived ``EaselDesignSystemCatalog``.
public enum DesignMarkdownEmitter {

  /// Renders a canonical `DESIGN.md`: YAML front matter in fixed category order
  /// followed by prose sections in canonical ``DesignSectionKind`` order
  /// (unrecognized sections preserved at the end).
  public static func emit(_ document: DesignMarkdown) -> String {
    var out = "---\n"
    out += frontMatter(document)
    out += "---\n"
    out += body(document)
    return out
  }

  // MARK: - Front matter

  private static func frontMatter(_ document: DesignMarkdown) -> String {
    var lines: [String] = []
    lines.append("version: \(document.version ?? "alpha")")
    lines.append("name: \(quoteIfNeeded(document.name))")
    if let detail = document.detail, !detail.isEmpty {
      lines.append("description: \(quoteIfNeeded(detail))")
    }

    if !document.colors.isEmpty {
      lines.append("colors:")
      for token in document.colors {
        lines.append("  \(quoteIfNeeded(token.name)): \(quoted(token.value))")
      }
    }

    if !document.typography.isEmpty {
      lines.append("typography:")
      for token in document.typography {
        lines.append("  \(quoteIfNeeded(token.name)):")
        appendTypographyProperty(&lines, "fontFamily", token.fontFamily)
        appendTypographyProperty(&lines, "fontSize", token.fontSize)
        appendTypographyProperty(&lines, "fontWeight", token.fontWeight)
        appendTypographyProperty(&lines, "lineHeight", token.lineHeight)
        appendTypographyProperty(&lines, "letterSpacing", token.letterSpacing)
        appendTypographyProperty(&lines, "fontFeature", token.fontFeature)
        appendTypographyProperty(&lines, "fontVariation", token.fontVariation)
      }
    }

    if !document.rounded.isEmpty {
      lines.append("rounded:")
      for token in document.rounded {
        lines.append("  \(quoteIfNeeded(token.name)): \(quoteIfNeeded(token.value))")
      }
    }

    if !document.spacing.isEmpty {
      lines.append("spacing:")
      for token in document.spacing {
        lines.append("  \(quoteIfNeeded(token.name)): \(quoteIfNeeded(token.value))")
      }
    }

    if !document.components.isEmpty {
      lines.append("components:")
      for component in document.components {
        lines.append("  \(quoteIfNeeded(component.name)):")
        for property in component.properties {
          let rendered: String
          switch property.value {
          case .reference(let reference): rendered = quoted(reference.rawString)
          case .literal(let value): rendered = quoteIfNeeded(value)
          }
          lines.append("    \(quoteIfNeeded(property.key)): \(rendered)")
        }
      }
    }

    return lines.joined(separator: "\n") + "\n"
  }

  private static func appendTypographyProperty(_ lines: inout [String], _ key: String, _ value: String?) {
    guard let value, !value.isEmpty else { return }
    lines.append("    \(key): \(quoteIfNeeded(value))")
  }

  // MARK: - Prose body

  private static func body(_ document: DesignMarkdown) -> String {
    let known = document.sections.enumerated()
      .filter { $0.element.kind != nil }
      .sorted { lhs, rhs in
        if lhs.element.kind!.rawValue != rhs.element.kind!.rawValue {
          return lhs.element.kind!.rawValue < rhs.element.kind!.rawValue
        }
        return lhs.offset < rhs.offset
      }
      .map(\.element)
    let unknown = document.sections.filter { $0.kind == nil }

    var out = ""
    for section in known + unknown {
      let title = section.kind?.canonicalTitle ?? section.title
      out += "\n## \(title)\n"
      if !section.body.isEmpty {
        out += "\n\(section.body)\n"
      }
    }
    return out
  }

  // MARK: - Scalar quoting

  private static func quoted(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }

  private static func quoteIfNeeded(_ value: String) -> String {
    if value.isEmpty { return "\"\"" }
    let specials = Set(":#{}[],&*!|>'\"%@`")
    let needsQuote = value.contains(where: { specials.contains($0) })
      || value.first == " "
      || value.last == " "
    return needsQuote ? quoted(value) : value
  }
}

// MARK: - Building a document from a Figma-derived catalog

extension DesignMarkdownEmitter {

  /// Upgrades a locally-extracted ``EaselDesignSystemCatalog`` into a
  /// spec-compliant ``DesignMarkdown``: semantic color/type naming, `radii →
  /// rounded`, effects rendered into the Elevation & Depth prose, and structured
  /// prose rationale for every populated section.
  public static func makeDocument(
    fromCatalog catalog: EaselDesignSystemCatalog,
    profile: EaselDesignSystemProfile
  ) -> DesignMarkdown {
    let tokens = catalog.tokens ?? .empty

    let colors = makeColorTokens(tokens.colors)
    let typography = makeTypographyTokens(tokens.typography)
    let rounded = makeDimensionTokens(tokens.radii, scale: roundedScaleNames)
    let spacing = makeDimensionTokens(tokens.spacing, scale: spacingScaleNames)
    let families = catalog.componentFamilies ?? []

    let detail = nonEmpty(catalog.summary) ?? nonEmpty(profile.blurb)

    var sections: [DesignSection] = []
    sections.append(section(.overview, overviewProse(profile: profile, catalog: catalog)))
    if !colors.isEmpty { sections.append(section(.colors, colorsProse(colors))) }
    if !typography.isEmpty { sections.append(section(.typography, typographyProse(typography))) }
    if !spacing.isEmpty { sections.append(section(.layout, layoutProse(spacing))) }
    if !tokens.effects.isEmpty { sections.append(section(.elevation, elevationProse(tokens.effects))) }
    if !rounded.isEmpty { sections.append(section(.shapes, shapesProse(rounded))) }
    if !families.isEmpty { sections.append(section(.components, componentsProse(families))) }
    sections.append(section(.dosAndDonts, dosAndDontsProse(catalog: catalog)))

    return DesignMarkdown(
      version: "alpha",
      name: profile.name,
      detail: detail,
      colors: colors,
      typography: typography,
      rounded: rounded,
      spacing: spacing,
      components: [],
      unknownFrontMatterKeys: [],
      sections: sections
    )
  }

  // MARK: Token heuristics

  private static let colorRoleNames = ["primary", "secondary", "tertiary", "neutral"]
  private static let typographyScaleNames = [
    "display-lg", "display-md", "display-sm",
    "headline-lg", "headline-md",
    "title-lg", "title-md",
    "body-lg", "body-md", "body-sm",
    "label-lg", "label-md", "label-sm",
  ]
  private static let roundedScaleNames = ["sm", "md", "lg", "xl", "2xl", "full"]
  private static let spacingScaleNames = ["xs", "sm", "md", "lg", "xl", "2xl", "3xl", "4xl"]

  private static func makeColorTokens(_ source: [EaselDesignSystemColorToken]) -> [DesignMarkdown.ColorToken] {
    let ranked = source.enumerated().sorted { lhs, rhs in
      if lhs.element.confidence != rhs.element.confidence { return lhs.element.confidence > rhs.element.confidence }
      return lhs.offset < rhs.offset
    }
    var used = Set<String>()
    return ranked.enumerated().map { index, entry in
      let base = index < colorRoleNames.count ? colorRoleNames[index] : "accent-\(index - colorRoleNames.count + 1)"
      return DesignMarkdown.ColorToken(name: uniqueName(base, &used), value: normalizeHex(entry.element.hex))
    }
  }

  private static func makeTypographyTokens(_ source: [EaselDesignSystemTypographyToken]) -> [DesignMarkdown.TypographyToken] {
    let ranked = source.enumerated().sorted { lhs, rhs in
      let lhsSize = lhs.element.fontSize ?? -1
      let rhsSize = rhs.element.fontSize ?? -1
      if lhsSize != rhsSize { return lhsSize > rhsSize }
      return lhs.offset < rhs.offset
    }
    var used = Set<String>()
    return ranked.enumerated().map { index, entry in
      let base = index < typographyScaleNames.count ? typographyScaleNames[index] : "body-\(index + 1)"
      var token = DesignMarkdown.TypographyToken(name: uniqueName(base, &used))
      token.fontFamily = nonEmpty(entry.element.fontFamily)
      if let size = entry.element.fontSize { token.fontSize = "\(Int(size.rounded()))px" }
      token.fontWeight = fontWeight(from: entry.element.fontStyle)
      return token
    }
  }

  private static func makeDimensionTokens(_ source: [EaselDesignSystemNumberToken], scale: [String]) -> [DesignMarkdown.DimensionToken] {
    let ranked = source.enumerated().sorted { lhs, rhs in
      if lhs.element.value != rhs.element.value { return lhs.element.value < rhs.element.value }
      return lhs.offset < rhs.offset
    }
    var used = Set<String>()
    return ranked.enumerated().map { index, entry in
      let base = index < scale.count ? scale[index] : "\(scale.last ?? "lg")-\(index + 1)"
      return DesignMarkdown.DimensionToken(name: uniqueName(base, &used), value: dimensionString(entry.element))
    }
  }

  // MARK: Prose builders

  private static func overviewProse(profile: EaselDesignSystemProfile, catalog: EaselDesignSystemCatalog) -> String {
    var parts: [String] = []
    if let blurb = nonEmpty(profile.blurb) { parts.append(blurb) }
    else if let summary = nonEmpty(catalog.summary) { parts.append(summary) }
    else { parts.append("\(profile.name) design system.") }
    if let notes = nonEmpty(profile.notes) { parts.append(notes) }
    if let disclaimer = nonEmpty(catalog.disclaimer) { parts.append("> \(disclaimer)") }
    return parts.joined(separator: "\n\n")
  }

  private static func colorsProse(_ colors: [DesignMarkdown.ColorToken]) -> String {
    var lines = ["The palette below is keyed by semantic role; reference colors as `{colors.<name>}`."]
    for color in colors {
      lines.append("- **\(color.name)** — `\(color.value)`")
    }
    return lines.joined(separator: "\n")
  }

  private static func typographyProse(_ typography: [DesignMarkdown.TypographyToken]) -> String {
    var lines = ["Type ramp, largest to smallest:"]
    for token in typography {
      let detail = [token.fontFamily, token.fontSize, token.fontWeight].compactMap { $0 }.joined(separator: " · ")
      lines.append("- **\(token.name)**\(detail.isEmpty ? "" : " — \(detail)")")
    }
    return lines.joined(separator: "\n")
  }

  private static func layoutProse(_ spacing: [DesignMarkdown.DimensionToken]) -> String {
    let scale = spacing.map { "\($0.name) (\($0.value))" }.joined(separator: ", ")
    return "Lay out with a consistent spacing scale: \(scale). Prefer containment and generous whitespace over decorative borders."
  }

  private static func elevationProse(_ effects: [EaselDesignSystemEffectToken]) -> String {
    var lines = ["Elevation is expressed through the following effects:"]
    for effect in effects {
      lines.append("- **\(effect.name)** — \(effect.kind)")
    }
    return lines.joined(separator: "\n")
  }

  private static func shapesProse(_ rounded: [DesignMarkdown.DimensionToken]) -> String {
    let scale = rounded.map { "\($0.name) (\($0.value))" }.joined(separator: ", ")
    return "Corner radii: \(scale). Apply radii consistently across related components."
  }

  private static func componentsProse(_ families: [EaselDesignSystemComponentFamily]) -> String {
    var lines: [String] = []
    for family in families {
      var line = "- **\(family.title)** (\(family.category))"
      if family.variantCount > 1 { line += " — \(family.variantCount) variants" }
      lines.append(line)
      for property in family.variantProperties.prefix(6) {
        lines.append("  - \(property.name): \(property.values.prefix(8).joined(separator: ", "))")
      }
    }
    return lines.joined(separator: "\n")
  }

  private static func dosAndDontsProse(catalog: EaselDesignSystemCatalog) -> String {
    var lines = [
      "- **Do** reuse the tokens above instead of hard-coding values.",
      "- **Do** maintain WCAG AA contrast (4.5:1 for body text).",
      "- **Don't** introduce off-system colors, type sizes, or radii.",
    ]
    if let warnings = catalog.sourceDiagnostics?.warnings, !warnings.isEmpty {
      lines.append("")
      lines.append("Import notes:")
      for warning in warnings.prefix(6) { lines.append("- \(warning)") }
    }
    return lines.joined(separator: "\n")
  }

  // MARK: Helpers

  private static func section(_ kind: DesignSectionKind, _ body: String) -> DesignSection {
    DesignSection(kind: kind, title: kind.canonicalTitle, body: body)
  }

  private static func uniqueName(_ base: String, _ used: inout Set<String>) -> String {
    var candidate = base
    var suffix = 2
    while used.contains(candidate) {
      candidate = "\(base)-\(suffix)"
      suffix += 1
    }
    used.insert(candidate)
    return candidate
  }

  private static func normalizeHex(_ hex: String) -> String {
    let trimmed = hex.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
  }

  private static func dimensionString(_ token: EaselDesignSystemNumberToken) -> String {
    let unit = token.unit.isEmpty ? "px" : token.unit
    if token.value == token.value.rounded() {
      return "\(Int(token.value))\(unit)"
    }
    return "\(token.value)\(unit)"
  }

  private static func fontWeight(from style: String?) -> String? {
    guard let style = style?.lowercased() else { return nil }
    if style.contains("thin") { return "100" }
    if style.contains("extralight") || style.contains("ultralight") { return "200" }
    if style.contains("semibold") { return "600" }
    if style.contains("light") { return "300" }
    if style.contains("medium") { return "500" }
    if style.contains("bold") { return "700" }
    if style.contains("black") || style.contains("heavy") { return "900" }
    if style.contains("regular") || style.contains("normal") { return "400" }
    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return nil
    }
    return trimmed
  }
}
