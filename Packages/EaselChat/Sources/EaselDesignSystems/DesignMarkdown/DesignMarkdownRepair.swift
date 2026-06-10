//
//  DesignMarkdownRepair.swift
//  EaselDesignSystems
//

import Foundation

/// Best-effort programmatic recovery for not-quite-valid `DESIGN.md` input so the
/// import path can succeed instead of hard-failing. Handles common problems:
/// missing YAML front matter (prose-only files) and a missing `name`. Prose-only
/// repair also extracts practical tokens from common design-system writeups:
/// color lists, type tables, spacing/radius scales, and component property lists.
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
      let document = try DesignMarkdownParser.parse(text)
      let enriched = enrichingSparseDocument(document, from: text)
      guard enriched != document else {
        return Result(document: document, didRepair: false, notes: [])
      }
      return Result(
        document: enriched,
        didRepair: true,
        notes: []
      )
    } catch DesignMarkdownParseError.missingFrontMatter {
      return Result(
        document: synthesizingDocument(for: text, fallbackName: fallbackName),
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

  private static func synthesizingDocument(for text: String, fallbackName: String?) -> DesignMarkdown {
    let normalized = bodyText(from: text)
    let document = DesignMarkdown(
      version: "alpha",
      name: resolvedName(fallbackName, from: normalized),
      detail: firstProseSummary(in: normalized),
      colors: extractColorTokens(from: normalized),
      typography: extractTypographyTokens(from: normalized),
      rounded: extractRoundedTokens(from: normalized),
      spacing: extractSpacingTokens(from: normalized),
      components: extractComponentTokens(from: normalized),
      unknownFrontMatterKeys: [],
      sections: parseSections(from: normalized)
    )
    return enrichingSparseDocument(document, from: normalized)
  }

  private static func enrichingSparseDocument(_ document: DesignMarkdown, from text: String) -> DesignMarkdown {
    let body = bodyText(from: text)
    let proseColors = extractColorTokens(from: body)
    let proseTypography = extractTypographyTokens(from: body)
    let proseRounded = extractRoundedTokens(from: body)
    let proseSpacing = extractSpacingTokens(from: body)
    let proseComponents = extractComponentTokens(from: body)

    var enriched = document
    if enriched.detail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
      enriched.detail = firstProseSummary(in: body)
    }
    if shouldPreferProseColors(existing: enriched.colors, prose: proseColors) {
      enriched.colors = proseColors
    }
    enriched.colors = ensuringPrimaryColor(in: enriched.colors)
    if enriched.typography.isEmpty {
      enriched.typography = proseTypography
    }
    if enriched.rounded.isEmpty {
      enriched.rounded = proseRounded
    }
    if enriched.spacing.isEmpty {
      enriched.spacing = proseSpacing
    }
    if enriched.components.isEmpty {
      enriched.components = proseComponents
    }
    if enriched != document {
      enriched.sections = canonicalSectionOrder(enriched.sections)
    }
    return enriched
  }

  private static func injectingName(into text: String, name: String) -> String {
    var lines = text.components(separatedBy: "\n")
    guard let openIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
      return text
    }
    lines.insert("name: \(quoted(name))", at: openIndex + 1)
    return lines.joined(separator: "\n")
  }

  // MARK: - Heuristics

  private static let roleNames = ["primary", "secondary", "tertiary", "neutral"]
  private static let spacingScaleNames = ["xs", "sm", "md", "lg", "xl", "2xl", "3xl", "4xl", "5xl", "6xl", "7xl", "8xl"]
  private static let fallbackRadiusNames = ["sm", "md", "lg", "xl", "2xl", "full"]
  private static let generatedAccentPrefix = "accent-"

  private struct MarkdownSection {
    var title: String
    var body: String
  }

  private struct MarkdownTable {
    var headers: [String]
    var rows: [[String]]
  }

  private struct ComponentDraft {
    var name: String
    var properties: [DesignMarkdown.ComponentProperty] = []
  }

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
      if !title.isEmpty { return displayName(fromHeading: title) }
    }
    return nil
  }

  private static func displayName(fromHeading heading: String) -> String {
    let prefixes = [
      "Design System Inspired by ",
      "Design System for ",
      "Design System: ",
    ]
    for prefix in prefixes {
      guard let range = heading.range(of: prefix, options: [.anchored, .caseInsensitive]) else { continue }
      let candidate = heading[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
      if !candidate.isEmpty { return candidate }
    }
    return heading
  }

  private static func firstProseSummary(in text: String) -> String? {
    var paragraph: [String] = []

    func flush() -> String? {
      let joined = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
      paragraph.removeAll()
      guard !joined.isEmpty else { return nil }
      return String(joined.prefix(220))
    }

    for raw in text.components(separatedBy: "\n") {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        if let summary = flush() { return summary }
        continue
      }
      guard !isMarkdownHeading(line), !line.hasPrefix("|"), !isListLine(line) else {
        continue
      }
      paragraph.append(stripMarkdown(line))
    }

    return flush()
  }

  // MARK: Sections

  private static func parseSections(from text: String) -> [DesignSection] {
    let parsed = rawSections(from: text)
    var sections: [DesignSection] = []

    let preamble = proseBody(from: parsed.preamble)
    if !preamble.isEmpty {
      sections.append(DesignSection(kind: .overview, title: DesignSectionKind.overview.canonicalTitle, body: preamble))
    }

    for section in parsed.sections {
      let body = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !body.isEmpty else { continue }
      sections.append(DesignSection(kind: DesignSectionKind.match(heading: section.title), title: section.title, body: body))
    }

    if sections.isEmpty {
      let body = proseBody(from: text)
      if !body.isEmpty {
        sections.append(DesignSection(kind: .overview, title: DesignSectionKind.overview.canonicalTitle, body: body))
      }
    }

    return canonicalSectionOrder(sections)
  }

  private static func rawSections(from text: String) -> (preamble: String, sections: [MarkdownSection]) {
    var preamble: [String] = []
    var sections: [MarkdownSection] = []
    var currentTitle: String?
    var currentBody: [String] = []

    func flush() {
      guard let currentTitle else { return }
      sections.append(MarkdownSection(
        title: currentTitle,
        body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      ))
      currentBody.removeAll()
    }

    for raw in text.components(separatedBy: "\n") {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("## "), !line.hasPrefix("### ") {
        flush()
        currentTitle = headingTitle(from: line)
      } else if currentTitle != nil {
        currentBody.append(raw)
      } else {
        preamble.append(raw)
      }
    }
    flush()

    return (preamble.joined(separator: "\n"), sections)
  }

  private static func canonicalSectionOrder(_ sections: [DesignSection]) -> [DesignSection] {
    let known = sections.enumerated()
      .filter { $0.element.kind != nil }
      .sorted { lhs, rhs in
        if lhs.element.kind!.rawValue != rhs.element.kind!.rawValue {
          return lhs.element.kind!.rawValue < rhs.element.kind!.rawValue
        }
        return lhs.offset < rhs.offset
      }
      .map(\.element)
    let unknown = sections.filter { $0.kind == nil }
    return known + unknown
  }

  private static func proseBody(from text: String) -> String {
    text.components(separatedBy: "\n")
      .filter { !isMarkdownHeading($0.trimmingCharacters(in: .whitespaces)) }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func headingTitle(from line: String) -> String {
    line.drop(while: { $0 == "#" })
      .trimmingCharacters(in: .whitespaces)
  }

  // MARK: Color extraction

  private static func shouldPreferProseColors(
    existing: [DesignMarkdown.ColorToken],
    prose: [DesignMarkdown.ColorToken]
  ) -> Bool {
    guard !prose.isEmpty else { return false }
    guard !existing.isEmpty else { return true }
    guard existing.allSatisfy({ isGeneratedColorName($0.name) }) else { return false }

    let existingValues = Set(existing.map { normalizedColorValue($0.value).lowercased() })
    let proseValues = Set(prose.map { normalizedColorValue($0.value).lowercased() })
    let sharedCount = existingValues.intersection(proseValues).count
    let requiredSharedCount = max(1, min(existingValues.count, proseValues.count) / 2)
    return sharedCount >= requiredSharedCount
  }

  private static func isGeneratedColorName(_ name: String) -> Bool {
    if roleNames.contains(name) { return true }
    guard name.hasPrefix(generatedAccentPrefix) else { return false }
    return Int(name.dropFirst(generatedAccentPrefix.count)) != nil
  }

  private static func extractColorTokens(from text: String) -> [DesignMarkdown.ColorToken] {
    let parsed = rawSections(from: text)
    let colorSections = parsed.sections.filter { isColorSection($0.title) }
    let source = colorSections.isEmpty ? text : colorSections.map(\.body).joined(separator: "\n")

    var seenValues = Set<String>()
    var usedNames = Set<String>()
    var tokens: [DesignMarkdown.ColorToken] = []

    for line in source.components(separatedBy: "\n") {
      for value in colorLiterals(in: line) {
        let normalized = normalizedColorValue(value)
        guard seenValues.insert(normalized.lowercased()).inserted else { continue }
        let fallback = tokens.count < roleNames.count ? roleNames[tokens.count] : "accent-\(tokens.count - roleNames.count + 1)"
        let name = uniqueSlug(colorName(from: line, fallback: fallback), used: &usedNames)
        tokens.append(DesignMarkdown.ColorToken(name: name, value: normalized))
      }
    }

    return Array(ensuringPrimaryColor(in: tokens).prefix(24))
  }

  private static func ensuringPrimaryColor(in tokens: [DesignMarkdown.ColorToken]) -> [DesignMarkdown.ColorToken] {
    guard !tokens.isEmpty,
          !tokens.contains(where: { $0.name == "primary" }) else {
      return tokens
    }

    return [DesignMarkdown.ColorToken(name: "primary", value: tokens[0].value)] + tokens
  }

  private static func colorLiterals(in line: String) -> [String] {
    var results: [String] = []
    for code in inlineCodeValues(in: line) {
      if let color = singleColorLiteral(from: code) {
        results.append(color)
      }
    }
    if results.isEmpty {
      results.append(contentsOf: hexColorLiterals(in: line))
    }
    return distinct(results)
  }

  private static func singleColorLiteral(from value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if isHexLiteral(trimmed) { return normalizedHex(trimmed) }

    let lower = trimmed.lowercased()
    let functionPrefixes = ["rgb(", "rgba(", "hsl(", "hsla(", "oklch(", "oklab(", "lab(", "lch("]
    guard functionPrefixes.contains(where: { lower.hasPrefix($0) }),
          lower.hasSuffix(")"),
          !lower.contains("px") else {
      return nil
    }
    return trimmed
  }

  private static func hexColorLiterals(in text: String) -> [String] {
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
        hexes.append("#" + run.uppercased())
      }
      index = cursor
    }
    return hexes
  }

  private static func colorName(from line: String, fallback: String) -> String {
    if let bold = inlineBoldValues(in: line).first {
      return bold
    }

    let prefix: String
    if let backtick = line.firstIndex(of: "`") {
      prefix = String(line[..<backtick])
    } else if let hash = line.firstIndex(of: "#") {
      prefix = String(line[..<hash])
    } else {
      prefix = line
    }

    var candidate = stripListMarker(prefix)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "(-: "))

    if let colon = candidate.lastIndex(of: ":") {
      candidate = String(candidate[..<colon])
    }
    candidate = stripMarkdown(candidate)
    return candidate.isEmpty ? fallback : candidate
  }

  // MARK: Typography extraction

  private static func extractTypographyTokens(from text: String) -> [DesignMarkdown.TypographyToken] {
    let parsed = rawSections(from: text)
    let typographySections = parsed.sections.filter { isTypographySection($0.title) }
    let source = typographySections.isEmpty ? text : typographySections.map(\.body).joined(separator: "\n")
    var usedNames = Set<String>()
    var tokens: [DesignMarkdown.TypographyToken] = []

    for table in markdownTables(in: source) {
      let headers = Dictionary(uniqueKeysWithValues: table.headers.enumerated().map { (normalizedTableHeader($0.element), $0.offset) })
      guard let roleIndex = headers["role"] else { continue }

      for row in table.rows {
        guard roleIndex < row.count else { continue }
        let role = cleanTableCell(row[roleIndex])
        guard !role.isEmpty else { continue }

        var token = DesignMarkdown.TypographyToken(name: uniqueSlug(role, used: &usedNames))
        if let font = tableValue("font", headers: headers, row: row).flatMap(nonEmpty) {
          token.fontFamily = font
        }
        if let size = tableValue("size", headers: headers, row: row).flatMap({ dimensionLiterals(in: $0).first }) {
          token.fontSize = size
        }
        if let weight = tableValue("weight", headers: headers, row: row).flatMap(fontWeightValue) {
          token.fontWeight = weight
        }
        if let lineHeight = tableValue("lineheight", headers: headers, row: row).flatMap(cleanMetricValue) {
          token.lineHeight = lineHeight
        }
        if let letterSpacing = tableValue("letterspacing", headers: headers, row: row).flatMap(cleanMetricValue) {
          token.letterSpacing = letterSpacing
        }
        tokens.append(token)
      }
    }

    return Array(tokens.prefix(24))
  }

  private static func tableValue(_ key: String, headers: [String: Int], row: [String]) -> String? {
    guard let index = headers[key], index < row.count else { return nil }
    return cleanTableCell(row[index])
  }

  private static func markdownTables(in source: String) -> [MarkdownTable] {
    let lines = source.components(separatedBy: "\n")
    var tables: [MarkdownTable] = []
    var index = 0

    while index + 1 < lines.count {
      guard isTableRow(lines[index]), isTableDivider(lines[index + 1]) else {
        index += 1
        continue
      }
      let headers = tableCells(lines[index])
      var rows: [[String]] = []
      index += 2
      while index < lines.count, isTableRow(lines[index]) {
        rows.append(tableCells(lines[index]))
        index += 1
      }
      tables.append(MarkdownTable(headers: headers, rows: rows))
    }

    return tables
  }

  private static func isTableRow(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
  }

  private static func isTableDivider(_ line: String) -> Bool {
    let cells = tableCells(line)
    guard !cells.isEmpty else { return false }
    return cells.allSatisfy { cell in
      let trimmed = cell.trimmingCharacters(in: .whitespaces)
      return !trimmed.isEmpty && trimmed.allSatisfy { $0 == "-" || $0 == ":" }
    }
  }

  private static func tableCells(_ line: String) -> [String] {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.first == "|" { trimmed.removeFirst() }
    if trimmed.last == "|" { trimmed.removeLast() }
    return trimmed.split(separator: "|", omittingEmptySubsequences: false).map { cleanTableCell(String($0)) }
  }

  private static func cleanTableCell(_ value: String) -> String {
    stripMarkdown(value)
      .replacingOccurrences(of: "\u{2013}", with: "-")
      .replacingOccurrences(of: "\u{2014}", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func normalizedTableHeader(_ value: String) -> String {
    cleanTableCell(value).lowercased().filter { $0.isLetter || $0.isNumber }
  }

  private static func fontWeightValue(_ value: String) -> String? {
    let lower = value.lowercased()
    if let number = firstInteger(in: value) { return number }
    if lower.contains("semibold") { return "600" }
    if lower.contains("medium") { return "500" }
    if lower.contains("bold") { return "700" }
    if lower.contains("regular") || lower.contains("normal") { return "400" }
    if lower.contains("light") { return "300" }
    return nil
  }

  private static func cleanMetricValue(_ value: String) -> String? {
    let trimmed = cleanTableCell(value)
    guard !trimmed.isEmpty, trimmed != "-" else { return nil }
    if let dimension = dimensionLiterals(in: trimmed).first { return dimension }
    if let paren = trimmed.firstIndex(of: "(") {
      let candidate = trimmed[..<paren].trimmingCharacters(in: .whitespaces)
      return candidate.isEmpty ? nil : candidate
    }
    return trimmed
  }

  // MARK: Dimension extraction

  private static func extractSpacingTokens(from text: String) -> [DesignMarkdown.DimensionToken] {
    let parsed = rawSections(from: text)
    let spacingSections = parsed.sections.filter { isSpacingSection($0.title) }
    let source = spacingSections.isEmpty ? text : spacingSections.map(\.body).joined(separator: "\n")
    var seen = Set<String>()
    var values: [String] = []

    for line in source.components(separatedBy: "\n") {
      let lower = line.lowercased()
      guard lower.contains("spacing") || lower.contains("scale") || lower.contains("base unit") || lower.contains("gap") else {
        continue
      }
      for dimension in dimensionLiterals(in: line) where seen.insert(dimension).inserted {
        values.append(dimension)
      }
    }

    return values.prefix(spacingScaleNames.count).enumerated().map { index, value in
      DesignMarkdown.DimensionToken(name: spacingScaleNames[index], value: value)
    }
  }

  private static func extractRoundedTokens(from text: String) -> [DesignMarkdown.DimensionToken] {
    let parsed = rawSections(from: text)
    let explicitRadiusSections = parsed.sections.filter { isRadiusSection($0.title) }
    let layoutSections = parsed.sections.filter { isSpacingSection($0.title) }
    let componentSections = parsed.sections.filter { isComponentSection($0.title) }
    let radiusSections = !explicitRadiusSections.isEmpty
      ? explicitRadiusSections
      : (!layoutSections.isEmpty ? layoutSections : componentSections)
    let source = radiusSections.isEmpty ? text : radiusSections.map(\.body).joined(separator: "\n")
    var seenValues = Set<String>()
    var usedNames = Set<String>()
    var tokens: [DesignMarkdown.DimensionToken] = []
    var inRadiusSubsection = false

    for line in source.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let lower = trimmed.lowercased()
      if trimmed.hasPrefix("### ") {
        inRadiusSubsection = lower.contains("radius") || lower.contains("radii") || lower.contains("shape")
        continue
      }
      guard inRadiusSubsection || lower.contains("radius") || lower.contains("radii") || lower.contains("rounded") else {
        continue
      }
      for dimension in dimensionLiterals(in: line) where seenValues.insert(dimension).inserted {
        let fallback = tokens.count < fallbackRadiusNames.count ? fallbackRadiusNames[tokens.count] : "radius-\(tokens.count + 1)"
        let name = uniqueSlug(dimensionName(from: line, fallback: fallback), used: &usedNames)
        tokens.append(DesignMarkdown.DimensionToken(name: name, value: dimension))
      }
    }

    return Array(tokens.prefix(16))
  }

  private static func dimensionName(from line: String, fallback: String) -> String {
    if let bold = inlineBoldValues(in: line).first {
      return bold
    }
    var candidate = stripListMarker(line)
    if let paren = candidate.firstIndex(of: "(") {
      candidate = String(candidate[..<paren])
    } else if let colon = candidate.firstIndex(of: ":") {
      candidate = String(candidate[..<colon])
    }
    candidate = stripMarkdown(candidate).trimmingCharacters(in: .whitespacesAndNewlines)
    return candidate.isEmpty ? fallback : candidate
  }

  private static func dimensionLiterals(in text: String) -> [String] {
    let chars = Array(text)
    var result: [String] = []
    var index = 0

    while index < chars.count {
      let startsNumber = chars[index].isNumber
      let startsSignedNumber = (chars[index] == "-" || chars[index] == "+")
        && index + 1 < chars.count
        && chars[index + 1].isNumber
      guard startsNumber || startsSignedNumber else {
        index += 1
        continue
      }

      let start = index
      if startsSignedNumber { index += 1 }
      var hasDigit = false
      while index < chars.count, chars[index].isNumber {
        hasDigit = true
        index += 1
      }
      if index < chars.count, chars[index] == "." {
        index += 1
        while index < chars.count, chars[index].isNumber {
          hasDigit = true
          index += 1
        }
      }

      var unit = ""
      while index < chars.count, chars[index].isLetter || chars[index] == "%" {
        unit.append(chars[index])
        index += 1
      }

      let lowerUnit = unit.lowercased()
      if hasDigit, ["px", "rem", "em"].contains(lowerUnit) {
        result.append(String(chars[start..<index]))
      }
    }

    return result
  }

  // MARK: Component extraction

  private static func extractComponentTokens(from text: String) -> [DesignMarkdown.ComponentToken] {
    let parsed = rawSections(from: text)
    let componentSections = parsed.sections.filter { isComponentSection($0.title) }
    guard !componentSections.isEmpty else { return [] }

    var drafts: [ComponentDraft] = []
    var currentCategory: String?
    var current: ComponentDraft?

    func flush() {
      guard let draft = current, !draft.properties.isEmpty else {
        current = nil
        return
      }
      drafts.append(draft)
      current = nil
    }

    for line in componentSections.map(\.body).joined(separator: "\n").components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("### ") {
        flush()
        currentCategory = headingTitle(from: trimmed)
        continue
      }
      if let title = standaloneBoldLine(trimmed) {
        flush()
        current = ComponentDraft(name: componentName(category: currentCategory, title: title))
        continue
      }
      guard let property = componentProperty(from: trimmed) else { continue }
      if current == nil {
        current = ComponentDraft(name: componentName(category: nil, title: currentCategory ?? "component"))
      }
      current?.properties.append(property)
    }
    flush()

    return drafts.prefix(40).map { draft in
      DesignMarkdown.ComponentToken(name: draft.name, properties: draft.properties)
    }
  }

  private static func standaloneBoldLine(_ line: String) -> String? {
    guard line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 else { return nil }
    let inner = line.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
    return inner.isEmpty ? nil : inner
  }

  private static func componentName(category: String?, title: String) -> String {
    let titleSlug = slugify(title)
    guard let category else { return titleSlug.isEmpty ? "component" : titleSlug }
    let categorySlug = slugify(category)
    guard categorySlug == "buttons", !titleSlug.contains("button") else {
      return titleSlug.isEmpty ? categorySlug : titleSlug
    }
    return "button-\(titleSlug)"
  }

  private static func componentProperty(from line: String) -> DesignMarkdown.ComponentProperty? {
    guard !line.hasPrefix("|") else { return nil }
    let stripped = stripListMarker(line)
    guard let colon = stripped.firstIndex(of: ":") else { return nil }
    let rawKey = String(stripped[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
    let rawValue = String(stripped[stripped.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawKey.isEmpty, !rawValue.isEmpty, rawKey.count <= 40 else { return nil }

    let key = canonicalComponentPropertyKey(rawKey)
    let value = componentPropertyValue(from: rawValue)
    guard !value.isEmpty else { return nil }
    return DesignMarkdown.ComponentProperty(key: key, value: .literal(value))
  }

  private static func canonicalComponentPropertyKey(_ key: String) -> String {
    let normalized = slugify(key)
    switch normalized {
    case "background", "background-color", "bg":
      return "backgroundColor"
    case "text", "text-color", "foreground", "foreground-color", "color":
      return "textColor"
    case "placeholder", "placeholder-color":
      return "placeholderColor"
    case "radius", "border-radius", "rounded", "corner-radius":
      return "rounded"
    case "box-shadow":
      return "shadow"
    case "use", "usage":
      return "description"
    default:
      return normalized
    }
  }

  private static func componentPropertyValue(from raw: String) -> String {
    if let code = inlineCodeValues(in: raw).first {
      return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return stripMarkdown(raw).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: Section routing

  private static func isColorSection(_ title: String) -> Bool {
    let lower = title.lowercased()
    return lower.contains("color") || lower.contains("palette")
  }

  private static func isTypographySection(_ title: String) -> Bool {
    let lower = title.lowercased()
    return lower.contains("typography") || lower.contains("type")
  }

  private static func isSpacingSection(_ title: String) -> Bool {
    let lower = title.lowercased()
    return lower.contains("spacing") || lower.contains("layout") || lower.contains("responsive")
  }

  private static func isRadiusSection(_ title: String) -> Bool {
    let lower = title.lowercased()
    return lower.contains("radius") || lower.contains("radii") || lower.contains("shape")
  }

  private static func isComponentSection(_ title: String) -> Bool {
    let lower = title.lowercased()
    return lower.contains("component") || lower.contains("styling")
  }

  // MARK: Shared parsing helpers

  private static func isWordCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "_"
  }

  private static func isMarkdownHeading(_ line: String) -> Bool {
    line.hasPrefix("#")
  }

  private static func isListLine(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
  }

  private static func stripListMarker(_ line: String) -> String {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
      trimmed.removeFirst(2)
      return trimmed.trimmingCharacters(in: .whitespaces)
    }
    var cursor = trimmed.startIndex
    while cursor < trimmed.endIndex, trimmed[cursor].isNumber {
      cursor = trimmed.index(after: cursor)
    }
    if cursor > trimmed.startIndex, cursor < trimmed.endIndex, trimmed[cursor] == "." {
      let next = trimmed.index(after: cursor)
      if next < trimmed.endIndex, trimmed[next].isWhitespace {
        return String(trimmed[next...]).trimmingCharacters(in: .whitespaces)
      }
    }
    return trimmed
  }

  private static func stripMarkdown(_ value: String) -> String {
    value
      .replacingOccurrences(of: "**", with: "")
      .replacingOccurrences(of: "`", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func inlineCodeValues(in line: String) -> [String] {
    delimitedValues(in: line, delimiter: "`")
  }

  private static func inlineBoldValues(in line: String) -> [String] {
    delimitedValues(in: line, delimiter: "**")
  }

  private static func delimitedValues(in line: String, delimiter: String) -> [String] {
    var values: [String] = []
    var searchStart = line.startIndex
    while let open = line.range(of: delimiter, range: searchStart..<line.endIndex) {
      let innerStart = open.upperBound
      guard let close = line.range(of: delimiter, range: innerStart..<line.endIndex) else { break }
      values.append(String(line[innerStart..<close.lowerBound]))
      searchStart = close.upperBound
    }
    return values
  }

  private static func isHexLiteral(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("#") else { return false }
    let hex = trimmed.dropFirst()
    guard [3, 4, 6, 8].contains(hex.count) else { return false }
    return hex.allSatisfy(\.isHexDigit)
  }

  private static func normalizedColorValue(_ value: String) -> String {
    isHexLiteral(value) ? normalizedHex(value) : value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func normalizedHex(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("#") ? "#" + trimmed.dropFirst().uppercased() : "#" + trimmed.uppercased()
  }

  private static func uniqueSlug(_ value: String, used: inout Set<String>) -> String {
    let slug = slugify(value)
    let base = slug.isEmpty ? "token" : slug
    var candidate = base
    var suffix = 2
    while used.contains(candidate) {
      candidate = "\(base)-\(suffix)"
      suffix += 1
    }
    used.insert(candidate)
    return candidate
  }

  private static func slugify(_ value: String) -> String {
    var result = ""
    var previousWasSeparator = false
    for scalar in value.lowercased().unicodeScalars {
      if CharacterSet.alphanumerics.contains(scalar) {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if !previousWasSeparator {
        result.append("-")
        previousWasSeparator = true
      }
    }
    return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
  }

  private static func distinct(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0.lowercased()).inserted }
  }

  private static func firstInteger(in value: String) -> String? {
    var current = ""
    for character in value {
      if character.isNumber {
        current.append(character)
      } else if !current.isEmpty {
        return current
      }
    }
    return current.isEmpty ? nil : current
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty, trimmed != "-" else {
      return nil
    }
    return trimmed
  }

  private static func normalizedText(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
  }

  private static func bodyText(from text: String) -> String {
    let normalized = normalizedText(text)
    let lines = normalized.components(separatedBy: "\n")
    guard let openIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
          lines[openIndex].trimmingCharacters(in: .whitespaces) == "---",
          let closeIndex = lines[(openIndex + 1)...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
          }) else {
      return normalized
    }
    return lines[(closeIndex + 1)...].joined(separator: "\n")
  }

  private static func quoted(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }
}
