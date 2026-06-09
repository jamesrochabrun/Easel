//
//  DesignMarkdownRepair.swift
//  EaselDesignSystems
//

import Foundation

/// Best-effort programmatic recovery for not-quite-valid `DESIGN.md` input so the
/// import path can succeed instead of hard-failing. Handles the two most common
/// problems: missing YAML front matter (prose-only files) and a missing `name`.
/// The repaired text is re-emitted canonically by the caller, so the synthesized
/// front matter only needs to parse.
public enum DesignMarkdownRepair {
  public struct Result: Sendable {
    public let document: DesignMarkdown
    public let didRepair: Bool
    /// Human-readable notes about what was auto-fixed, surfaced as diagnostics.
    public let notes: [String]
  }

  /// Parses `text`, repairing missing front matter / name when needed. Re-throws
  /// the original parse error only when repair cannot help (e.g. malformed fences).
  public static func parse(_ text: String, fallbackName: String?) throws -> Result {
    do {
      return Result(document: try DesignMarkdownParser.parse(text), didRepair: false, notes: [])
    } catch DesignMarkdownParseError.missingFrontMatter {
      let repaired = synthesizingFrontMatter(for: text, fallbackName: fallbackName)
      return Result(
        document: try DesignMarkdownParser.parse(repaired),
        didRepair: true,
        notes: ["YAML front matter was missing and generated automatically — review the tokens."]
      )
    } catch DesignMarkdownParseError.missingName {
      let repaired = injectingName(into: text, name: resolvedName(fallbackName, from: text))
      return Result(
        document: try DesignMarkdownParser.parse(repaired),
        didRepair: true,
        notes: ["A `name` was missing and added automatically."]
      )
    }
  }

  // MARK: - Synthesis

  private static func synthesizingFrontMatter(for text: String, fallbackName: String?) -> String {
    let name = resolvedName(fallbackName, from: text)
    var lines = ["---", "version: alpha", "name: \(quoted(name))"]

    let colors = extractColors(from: text)
    if !colors.isEmpty {
      lines.append("colors:")
      for (tokenName, hex) in colors {
        lines.append("  \(tokenName): \(quoted(hex))")
      }
    }
    lines.append("---")

    return lines.joined(separator: "\n") + "\n\n" + ensuringSection(text)
  }

  private static func injectingName(into text: String, name: String) -> String {
    var lines = text.components(separatedBy: "\n")
    guard let openIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
      return text
    }
    lines.insert("name: \(quoted(name))", at: openIndex + 1)
    return lines.joined(separator: "\n")
  }

  /// Wraps prose under an `## Overview` heading when the body has no `##` sections,
  /// so the parser captures it (it only splits on `## `).
  private static func ensuringSection(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasSection = trimmed
      .components(separatedBy: "\n")
      .contains { $0.hasPrefix("## ") && !$0.hasPrefix("### ") }
    return hasSection ? trimmed : "## Overview\n\n\(trimmed)"
  }

  // MARK: - Heuristics

  private static let roleNames = ["primary", "secondary", "tertiary", "neutral"]

  private static func resolvedName(_ fallback: String?, from text: String) -> String {
    if let fallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines), !fallback.isEmpty {
      return fallback
    }
    return firstHeading(in: text) ?? "Untitled Design System"
  }

  private static func firstHeading(in text: String) -> String? {
    for raw in text.components(separatedBy: "\n") {
      let line = raw.trimmingCharacters(in: .whitespaces)
      guard line.hasPrefix("#") else { continue }
      let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
      if !title.isEmpty { return title }
    }
    return nil
  }

  /// Extracts up to 8 unique hex colors from the prose and assigns semantic
  /// names (markdown `#` headings are skipped since they aren't hex runs).
  private static func extractColors(from text: String) -> [(String, String)] {
    var seen = Set<String>()
    var hexes: [String] = []
    let chars = Array(text)
    var index = 0
    while index < chars.count {
      guard chars[index] == "#" else {
        index += 1
        continue
      }
      var cursor = index + 1
      var run = ""
      while cursor < chars.count, chars[cursor].isHexDigit {
        run.append(chars[cursor])
        cursor += 1
      }
      let followedByWord = cursor < chars.count && isWordCharacter(chars[cursor])
      if [3, 4, 6, 8].contains(run.count), !followedByWord {
        let hex = "#" + run.uppercased()
        if seen.insert(hex).inserted { hexes.append(hex) }
      }
      index = cursor
    }

    return hexes.prefix(8).enumerated().map { offset, hex in
      let name = offset < roleNames.count ? roleNames[offset] : "accent-\(offset - roleNames.count + 1)"
      return (name, hex)
    }
  }

  private static func isWordCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "_"
  }

  private static func quoted(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }
}
