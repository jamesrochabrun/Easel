//
//  DesignSystemBriefBuilder.swift
//  EaselChat
//

import EaselDesignSystems
import Foundation

/// Builds a compact, agent-readable Markdown brief of a custom design system so
/// the agent can reuse its tokens and components. The full `catalog.json` (with
/// preview scenes/assets) stays in the design system folder; this is the
/// condensed spec copied into each project that references the design system.
enum DesignSystemBriefBuilder {
  static func markdown(
    displayName: String,
    detail: String?,
    notes: String?,
    catalog: EaselDesignSystemCatalog?
  ) -> String {
    var lines: [String] = ["# Design system: \(displayName)", ""]

    if let detail = trimmed(detail) {
      lines.append(detail)
      lines.append("")
    }
    if let disclaimer = trimmed(catalog?.disclaimer) {
      lines.append("> \(disclaimer)")
      lines.append("")
    }
    lines.append("Reuse these colors, type, spacing, and component patterns when building this project's UI.")
    lines.append("")

    if let tokens = catalog?.tokens {
      if !tokens.colors.isEmpty {
        lines.append("## Colors")
        for color in tokens.colors.prefix(24) {
          lines.append("- \(color.name) — `\(color.hex)`")
        }
        lines.append("")
      }
      if !tokens.typography.isEmpty {
        lines.append("## Typography")
        for style in tokens.typography.prefix(16) {
          let parts = [
            style.fontFamily,
            style.fontStyle,
            style.fontSize.map { "\(Int($0.rounded()))px" },
          ].compactMap { $0 }
          lines.append("- \(style.name) — \(parts.joined(separator: ", "))")
        }
        lines.append("")
      }
      if !tokens.spacing.isEmpty {
        lines.append("## Spacing")
        lines.append(tokens.spacing.prefix(16).map { "\(Int($0.value.rounded()))\($0.unit)" }.joined(separator: ", "))
        lines.append("")
      }
      if !tokens.radii.isEmpty {
        lines.append("## Radii")
        lines.append(tokens.radii.prefix(16).map { "\(Int($0.value.rounded()))\($0.unit)" }.joined(separator: ", "))
        lines.append("")
      }
      if !tokens.effects.isEmpty {
        lines.append("## Effects")
        for effect in tokens.effects.prefix(12) {
          lines.append("- \(effect.name) — \(effect.kind)")
        }
        lines.append("")
      }
    }

    if let families = catalog?.componentFamilies, !families.isEmpty {
      let indexedFamilies = families.filter(\.isHighSignalIndexEntry)
      if !indexedFamilies.isEmpty {
        lines.append("## Component families")
      }
      for family in indexedFamilies.prefix(40) {
        var line = "- **\(family.title)** (\(family.category))"
        if family.variantCount > 1 {
          line += " — \(family.variantCount) variants"
        }
        lines.append(line)
        for property in family.variantProperties.prefix(6) {
          lines.append("  - \(property.name): \(property.values.prefix(8).joined(separator: ", "))")
        }
      }
      let omittedCount = families.count - indexedFamilies.count
      if omittedCount > 0 {
        if !indexedFamilies.isEmpty {
          lines.append("")
        }
        let pluralSuffix = omittedCount == 1 ? "" : "s"
        lines.append(
          "_Omitted \(omittedCount) low-signal one-off component candidate\(pluralSuffix) from this brief._"
        )
      }
      if !indexedFamilies.isEmpty || omittedCount > 0 {
        lines.append("")
      }
    }

    if let notes = trimmed(notes) {
      lines.append("## Brand notes")
      lines.append(notes)
      lines.append("")
    }

    if catalog == nil {
      lines.append("_Token and component details are still being extracted from the source file; this brief will be richer once extraction finishes._")
      lines.append("")
    }

    return lines.joined(separator: "\n")
  }

  private static func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
