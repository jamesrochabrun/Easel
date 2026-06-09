//
//  DesignMarkdownCatalogMapper.swift
//  EaselDesignSystems
//

import Foundation

/// Projects a canonical ``DesignMarkdown`` into the derived display feed
/// (`catalog.json`) that powers `index.html`, resolving token references to
/// concrete values and bridging the spec's category names to Easel's
/// (`rounded → radii`). When `preservingFrom` is supplied (the Figma path),
/// Figma-only richness — preview scenes, examples, assets, diagnostics — is
/// carried through unchanged while the token sections are re-derived.
public enum DesignMarkdownCatalogMapper {

  public static func makeTokenSet(
    from document: DesignMarkdown,
    preservingEffects effects: [EaselDesignSystemEffectToken] = []
  ) -> EaselDesignSystemTokenSet {
    EaselDesignSystemTokenSet(
      colors: document.colors.map { token in
        EaselDesignSystemColorToken(
          id: token.name,
          name: token.name,
          hex: resolvedColor(token.value, in: document),
          sourceNodeID: nil,
          sourceNodeName: nil,
          confidence: 0.9
        )
      },
      typography: document.typography.map { token in
        EaselDesignSystemTypographyToken(
          id: token.name,
          name: token.name,
          fontFamily: token.fontFamily ?? "",
          fontStyle: token.fontWeight,
          fontSize: token.fontSize.flatMap(pixelValue),
          sourceNodeID: nil,
          sourceNodeName: nil,
          confidence: 0.9
        )
      },
      spacing: document.spacing.map { numberToken($0) },
      radii: document.rounded.map { numberToken($0) },
      effects: effects
    )
  }

  public static func makeCatalog(
    from document: DesignMarkdown,
    profile: EaselDesignSystemProfile,
    preservingFrom existing: EaselDesignSystemCatalog? = nil,
    generatedAt: Date? = nil,
    lintWarnings: [String] = []
  ) -> EaselDesignSystemCatalog {
    let tokens = makeTokenSet(from: document, preservingEffects: existing?.tokens?.effects ?? [])
    let families = existing?.componentFamilies ?? componentFamilies(from: document)

    return EaselDesignSystemCatalog(
      name: document.name,
      summary: document.detail ?? existing?.summary ?? overviewSummary(document) ?? "\(document.name) design system.",
      generatedAt: generatedAt ?? existing?.generatedAt,
      componentGroups: existing?.componentGroups ?? [],
      title: document.name,
      isReference: existing?.isReference ?? false,
      disclaimer: existing?.disclaimer,
      tokens: tokens,
      componentFamilies: families,
      examples: existing?.examples,
      assets: existing?.assets,
      heroThumbnailPath: existing?.heroThumbnailPath,
      sourceDiagnostics: mergedDiagnostics(existing: existing?.sourceDiagnostics, lintWarnings: lintWarnings)
    )
  }

  /// Surfaces DESIGN.md lint warnings in the catalog's diagnostics panel
  /// (rendered by `index.html`), merging with any Figma import diagnostics.
  private static func mergedDiagnostics(
    existing: EaselDesignSystemSourceDiagnostics?,
    lintWarnings: [String]
  ) -> EaselDesignSystemSourceDiagnostics? {
    let warnings = lintWarnings.map { "DESIGN.md: \($0)" }
    if let existing {
      guard !warnings.isEmpty else { return existing }
      return EaselDesignSystemSourceDiagnostics(
        parsedCount: existing.parsedCount,
        failedCount: existing.failedCount,
        skippedCount: existing.skippedCount,
        totalNodeCount: existing.totalNodeCount,
        parserName: existing.parserName,
        parserVersion: existing.parserVersion,
        warnings: existing.warnings + warnings
      )
    }
    guard !warnings.isEmpty else { return nil }
    return EaselDesignSystemSourceDiagnostics(
      parsedCount: 0,
      failedCount: 0,
      skippedCount: 0,
      totalNodeCount: 0,
      parserName: "DESIGN.md linter",
      parserVersion: nil,
      warnings: warnings
    )
  }

  // MARK: - Components from spec tokens

  private static let stateSuffixes = ["hover", "active", "pressed", "focus", "focused", "disabled", "selected"]

  private static func componentFamilies(from document: DesignMarkdown) -> [EaselDesignSystemComponentFamily]? {
    guard !document.components.isEmpty else { return nil }

    var order: [String] = []
    var states: [String: [String]] = [:]
    var representative: [String: DesignMarkdown.ComponentToken] = [:]
    for component in document.components {
      let parts = component.name.split(separator: "-").map(String.init)
      let (base, state): (String, String)
      if let last = parts.last, parts.count > 1, stateSuffixes.contains(last.lowercased()) {
        base = parts.dropLast().joined(separator: "-")
        state = last
      } else {
        base = component.name
        state = "default"
      }
      if states[base] == nil { order.append(base) }
      states[base, default: []].append(state)
      // Prefer the default (non-state) entry as the family's representative.
      if representative[base] == nil || state == "default" {
        representative[base] = component
      }
    }

    return order.map { base in
      let values = states[base] ?? ["default"]
      let variantProperties = values.count > 1
        ? [EaselDesignSystemVariantProperty(id: "\(base).state", name: "State", values: values)]
        : []
      let component = representative[base]
      return EaselDesignSystemComponentFamily(
        id: base,
        title: humanize(base),
        category: "Components",
        summary: component.flatMap { propertyString($0, "description") } ?? "",
        sourcePage: nil,
        variantCount: values.count,
        variantProperties: variantProperties,
        preview: component.map { previewScene(for: $0, base: base, in: document) },
        confidence: 0.9
      )
    }
  }

  /// A schematic, token-driven preview for an imported/prompt component (Figma
  /// imports carry their own scenes). Renders the component's surface — its
  /// `backgroundColor`, `rounded` radius, and a label in `textColor` — on a soft
  /// backdrop so the catalog cards aren't empty.
  private static func previewScene(
    for component: DesignMarkdown.ComponentToken,
    base: String,
    in document: DesignMarkdown
  ) -> EaselDesignSystemPreviewScene {
    let width = 400.0
    let height = 250.0
    let backdrop = "#f4f4f5"
    let surface = propertyColor(component, "backgroundColor", in: document) ?? "#ffffff"
    let text = propertyColor(component, "textColor", in: document) ?? "#1b1b1b"
    let radius = min(propertyDimension(component, "rounded", in: document) ?? 12, 60)

    let rectX = 56.0, rectY = 86.0, rectW = 288.0, rectH = 78.0
    let layers: [EaselDesignSystemPreviewLayer] = [
      EaselDesignSystemPreviewLayer(id: "\(base).backdrop", kind: .rect, x: 0, y: 0, width: width, height: height, fill: backdrop),
      EaselDesignSystemPreviewLayer(id: "\(base).surface", kind: .rect, x: rectX, y: rectY, width: rectW, height: rectH, cornerRadius: radius, fill: surface, stroke: "#e3e3e3", strokeWidth: 1),
      EaselDesignSystemPreviewLayer(id: "\(base).label", kind: .text, x: rectX + 22, y: rectY + 28, width: rectW - 44, height: 28, text: humanize(base), fontSize: 20, fontWeight: "600", textColor: text),
    ]
    return EaselDesignSystemPreviewScene(width: width, height: height, background: backdrop, layers: layers)
  }

  private static func propertyString(_ component: DesignMarkdown.ComponentToken, _ key: String) -> String? {
    guard let property = component.properties.first(where: { $0.key == key }),
          case .literal(let value) = property.value,
          !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func propertyColor(_ component: DesignMarkdown.ComponentToken, _ key: String, in document: DesignMarkdown) -> String? {
    guard let property = component.properties.first(where: { $0.key == key }) else { return nil }
    let resolved = resolvedColor(property.value.rawString, in: document)
    return resolved.isEmpty ? nil : resolved
  }

  private static func propertyDimension(_ component: DesignMarkdown.ComponentToken, _ key: String, in document: DesignMarkdown) -> Double? {
    guard let property = component.properties.first(where: { $0.key == key }) else { return nil }
    let raw: String
    switch property.value {
    case .literal(let value): raw = value
    case .reference(let reference): raw = document.resolvedLiteral(for: reference) ?? ""
    }
    guard !raw.isEmpty else { return nil }
    return pixels(from: raw).value
  }

  // MARK: - Value helpers

  private static func resolvedColor(_ raw: String, in document: DesignMarkdown) -> String {
    let resolved: String
    if let reference = TokenReference(raw: raw), let value = document.resolvedLiteral(for: reference) {
      resolved = value
    } else {
      resolved = raw
    }
    let trimmed = resolved.trimmingCharacters(in: .whitespaces)
    // Keep non-hex CSS colors verbatim (valid as a swatch background); normalize
    // a bare hex by ensuring the leading `#`.
    if isLikelyBareHex(trimmed) { return "#\(trimmed)" }
    return trimmed
  }

  private static func numberToken(_ token: DesignMarkdown.DimensionToken) -> EaselDesignSystemNumberToken {
    let (value, unit) = pixels(from: token.value)
    return EaselDesignSystemNumberToken(
      id: token.name,
      name: token.name,
      value: value,
      unit: unit,
      sourceNodeID: nil,
      sourceNodeName: nil,
      confidence: 0.9
    )
  }

  private static func pixelValue(_ dimension: String) -> Double? {
    let (value, _) = pixels(from: dimension)
    return value
  }

  /// Parses a dimension string into a pixel value, converting `rem`/`em`
  /// (16px base) and defaulting a unitless value to `px`.
  private static func pixels(from dimension: String) -> (value: Double, unit: String) {
    var number = ""
    var unit = ""
    for ch in dimension.trimmingCharacters(in: .whitespaces) {
      if ch.isNumber || ch == "." || ch == "-" || ch == "+" {
        number.append(ch)
      } else {
        unit.append(ch)
      }
    }
    let raw = Double(number) ?? 0
    switch unit.trimmingCharacters(in: .whitespaces).lowercased() {
    case "rem", "em": return (raw * 16, "px")
    case "", "px": return (raw, "px")
    case let other: return (raw, other)
    }
  }

  private static func isLikelyBareHex(_ value: String) -> Bool {
    guard !value.hasPrefix("#") else { return false }
    let counts = [3, 4, 6, 8]
    guard counts.contains(value.count) else { return false }
    return value.unicodeScalars.allSatisfy {
      ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") || ($0 >= "A" && $0 <= "F")
    }
  }

  private static func overviewSummary(_ document: DesignMarkdown) -> String? {
    guard let overview = document.sections.first(where: { $0.kind == .overview }) else { return nil }
    let firstLine = overview.body
      .components(separatedBy: "\n")
      .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    return firstLine?.trimmingCharacters(in: .whitespaces)
  }

  private static func humanize(_ slug: String) -> String {
    slug
      .split(whereSeparator: { $0 == "-" || $0 == "_" })
      .map { $0.prefix(1).uppercased() + $0.dropFirst() }
      .joined(separator: " ")
  }
}
