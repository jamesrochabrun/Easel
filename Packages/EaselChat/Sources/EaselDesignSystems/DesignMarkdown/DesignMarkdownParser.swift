//
//  DesignMarkdownParser.swift
//  EaselDesignSystems
//

import Foundation

public enum DesignMarkdownParseError: LocalizedError, Equatable, Sendable {
  case missingFrontMatter
  case unterminatedFrontMatter
  case missingName

  public var errorDescription: String? {
    switch self {
    case .missingFrontMatter:
      return "DESIGN.md is missing its YAML front matter (a leading `---` block)."
    case .unterminatedFrontMatter:
      return "DESIGN.md front matter is missing its closing `---` fence."
    case .missingName:
      return "DESIGN.md front matter is missing the required `name` field."
    }
  }
}

/// Parses `DESIGN.md` text (YAML front matter + markdown body) into a
/// ``DesignMarkdown`` value.
///
/// The front-matter parser handles the block-style YAML subset the spec uses:
/// scalar top-level keys plus nested block mappings (≤ a few levels), quoted or
/// unquoted scalars, inline `#` comments outside quotes, and `{token.ref}`
/// values (treated as scalars). Token references are stored unresolved so the
/// document round-trips stably.
public enum DesignMarkdownParser {

  public static func parse(_ markdown: String) throws -> DesignMarkdown {
    let normalized = markdown
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let (frontMatter, body) = try splitFrontMatter(normalized)
    let tree = parseBlockMapping(frontMatter)

    var version: String?
    var name: String?
    var detail: String?
    var colors: [DesignMarkdown.ColorToken] = []
    var typography: [DesignMarkdown.TypographyToken] = []
    var rounded: [DesignMarkdown.DimensionToken] = []
    var spacing: [DesignMarkdown.DimensionToken] = []
    var components: [DesignMarkdown.ComponentToken] = []
    var unknownKeys: [String] = []

    for (key, node) in tree {
      switch key {
      case "version": version = node.scalar?.nilIfEmpty
      case "name": name = node.scalar?.nilIfEmpty
      case "description": detail = node.scalar?.nilIfEmpty
      case "colors": colors = colorTokens(from: node)
      case "typography": typography = typographyTokens(from: node)
      case "rounded": rounded = dimensionTokens(from: node)
      case "spacing": spacing = dimensionTokens(from: node)
      case "components": components = componentTokens(from: node)
      default: unknownKeys.append(key)
      }
    }

    guard let resolvedName = name else { throw DesignMarkdownParseError.missingName }

    return DesignMarkdown(
      version: version,
      name: resolvedName,
      detail: detail,
      colors: colors,
      typography: typography,
      rounded: rounded,
      spacing: spacing,
      components: components,
      unknownFrontMatterKeys: unknownKeys,
      sections: parseSections(body)
    )
  }

  // MARK: - Front-matter split

  private static func splitFrontMatter(_ text: String) throws -> (frontMatter: String, body: String) {
    let lines = text.components(separatedBy: "\n")
    guard let openIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
          lines[openIndex].trimmingCharacters(in: .whitespaces) == "---" else {
      throw DesignMarkdownParseError.missingFrontMatter
    }
    guard let closeIndex = lines[(openIndex + 1)...].firstIndex(where: {
      $0.trimmingCharacters(in: .whitespaces) == "---"
    }) else {
      throw DesignMarkdownParseError.unterminatedFrontMatter
    }
    let frontMatter = lines[(openIndex + 1)..<closeIndex].joined(separator: "\n")
    let body = lines[(closeIndex + 1)...].joined(separator: "\n")
    return (frontMatter, body)
  }

  // MARK: - Block YAML

  /// An ordered YAML node: a scalar string or an ordered mapping.
  private indirect enum YAMLNode {
    case scalar(String)
    case mapping([(String, YAMLNode)])

    var scalar: String? {
      if case .scalar(let value) = self { return value }
      return nil
    }

    var mapping: [(String, YAMLNode)] {
      if case .mapping(let pairs) = self { return pairs }
      return []
    }
  }

  private struct YAMLLine {
    let indent: Int
    let key: String
    let value: String?
  }

  private static func parseBlockMapping(_ yaml: String) -> [(String, YAMLNode)] {
    let lines = yaml.components(separatedBy: "\n").compactMap(parseLine)
    var index = 0
    return parseBlock(lines, &index, indent: lines.first?.indent ?? 0)
  }

  private static func parseBlock(
    _ lines: [YAMLLine],
    _ index: inout Int,
    indent: Int
  ) -> [(String, YAMLNode)] {
    var result: [(String, YAMLNode)] = []
    while index < lines.count {
      let line = lines[index]
      if line.indent < indent { break }
      if line.indent > indent {
        // Orphaned deeper line without a parent key — skip for robustness.
        index += 1
        continue
      }
      index += 1
      if let value = line.value, !value.isEmpty {
        result.append((line.key, .scalar(value)))
      } else if index < lines.count, lines[index].indent > indent {
        let childIndent = lines[index].indent
        let children = parseBlock(lines, &index, indent: childIndent)
        result.append((line.key, .mapping(children)))
      } else {
        result.append((line.key, .scalar("")))
      }
    }
    return result
  }

  /// Parses one source line into indentation + key/value, returning `nil` for
  /// blank lines, full-line comments, and list items (unsupported in the spec).
  private static func parseLine(_ raw: String) -> YAMLLine? {
    let chars = Array(raw)
    let indent = chars.prefix { $0 == " " || $0 == "\t" }.count
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("- ") {
      return nil
    }
    let content = stripInlineComment(trimmed)
    guard let (key, value) = splitKeyValue(content) else { return nil }
    return YAMLLine(indent: indent, key: key, value: value)
  }

  private static func stripInlineComment(_ content: String) -> String {
    var inSingle = false
    var inDouble = false
    var previous: Character?
    var result = ""
    for ch in content {
      if ch == "\"", !inSingle { inDouble.toggle() }
      else if ch == "'", !inDouble { inSingle.toggle() }
      else if ch == "#", !inSingle, !inDouble,
              previous == nil || previous == " " || previous == "\t" {
        break
      }
      result.append(ch)
      previous = ch
    }
    return result.trimmingCharacters(in: .whitespaces)
  }

  /// Splits `key: value` on the first quote-free colon. Returns the unquoted key
  /// and value (value `nil` when absent, signalling a nested/empty mapping key).
  private static func splitKeyValue(_ content: String) -> (key: String, value: String?)? {
    var inSingle = false
    var inDouble = false
    var colonIndex: Int?
    let chars = Array(content)
    for (offset, ch) in chars.enumerated() {
      if ch == "\"", !inSingle { inDouble.toggle() }
      else if ch == "'", !inDouble { inSingle.toggle() }
      else if ch == ":", !inSingle, !inDouble {
        colonIndex = offset
        break
      }
    }
    guard let colonIndex else { return nil }
    let rawKey = String(chars[..<colonIndex]).trimmingCharacters(in: .whitespaces)
    let rawValue = String(chars[(colonIndex + 1)...]).trimmingCharacters(in: .whitespaces)
    let key = unquote(rawKey)
    guard !key.isEmpty else { return nil }
    return (key, rawValue.isEmpty ? nil : unquote(rawValue))
  }

  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    let first = value.first!
    let last = value.last!
    guard first == last, first == "\"" || first == "'" else { return value }
    let inner = String(value.dropFirst().dropLast())
    if first == "\"" {
      return inner
        .replacingOccurrences(of: "\\\"", with: "\"")
        .replacingOccurrences(of: "\\\\", with: "\\")
    }
    return inner
  }

  // MARK: - Token extraction

  private static func colorTokens(from node: YAMLNode) -> [DesignMarkdown.ColorToken] {
    node.mapping.compactMap { name, value in
      guard let scalar = value.scalar else { return nil }
      return DesignMarkdown.ColorToken(name: name, value: scalar)
    }
  }

  private static func dimensionTokens(from node: YAMLNode) -> [DesignMarkdown.DimensionToken] {
    node.mapping.compactMap { name, value in
      guard let scalar = value.scalar else { return nil }
      return DesignMarkdown.DimensionToken(name: name, value: scalar)
    }
  }

  private static func typographyTokens(from node: YAMLNode) -> [DesignMarkdown.TypographyToken] {
    node.mapping.map { name, value in
      var token = DesignMarkdown.TypographyToken(name: name)
      for (key, child) in value.mapping {
        guard let scalar = child.scalar else { continue }
        switch key {
        case "fontFamily": token.fontFamily = scalar
        case "fontSize": token.fontSize = scalar
        case "fontWeight": token.fontWeight = scalar
        case "lineHeight": token.lineHeight = scalar
        case "letterSpacing": token.letterSpacing = scalar
        case "fontFeature": token.fontFeature = scalar
        case "fontVariation": token.fontVariation = scalar
        default: token.unknownKeys.append(key)
        }
      }
      return token
    }
  }

  private static func componentTokens(from node: YAMLNode) -> [DesignMarkdown.ComponentToken] {
    node.mapping.map { name, value in
      let properties = value.mapping.compactMap { key, child -> DesignMarkdown.ComponentProperty? in
        guard let scalar = child.scalar else { return nil }
        return DesignMarkdown.ComponentProperty(key: key, value: DesignTokenValue(raw: scalar))
      }
      return DesignMarkdown.ComponentToken(name: name, properties: properties)
    }
  }

  // MARK: - Section parsing

  private static func parseSections(_ body: String) -> [DesignSection] {
    let lines = body.components(separatedBy: "\n")
    var sections: [DesignSection] = []
    var currentTitle: String?
    var currentBody: [String] = []

    func flush() {
      guard let title = currentTitle else { return }
      let text = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      sections.append(DesignSection(kind: DesignSectionKind.match(heading: title), title: title, body: text))
      currentBody = []
    }

    for line in lines {
      if line.hasPrefix("## "), !line.hasPrefix("### ") {
        flush()
        currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
      } else if currentTitle != nil {
        currentBody.append(line)
      }
    }
    flush()
    return sections
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}
