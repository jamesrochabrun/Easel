//
//  WebPreviewStyleProvenance.swift
//  EaselWebInspector
//
//  Per-property winning-declaration provenance computed in-page from CSSOM.
//  A property is only eligible for a Tier-1 direct write when its winner has
//  a rule locator and no uncertainty flags; everything else stays agent-applied.
//

import Foundation

/// Locates one CSS rule inside a runtime stylesheet so it can be matched
/// against a file on disk.
public struct WebPreviewCSSRuleLocator: Hashable, Sendable {
  public let stylesheetHref: String?
  public let styleSheetIndex: Int
  public let ruleIndexPath: [Int]
  public let selectorText: String
  public let specificity: [Int]
  /// Attributes of the owning `<style>`/`<link>` node (captures dev-server
  /// markers like `data-vite-dev-id`).
  public let ownerNodeAttributes: [String: String]

  public init(
    stylesheetHref: String?,
    styleSheetIndex: Int,
    ruleIndexPath: [Int],
    selectorText: String,
    specificity: [Int],
    ownerNodeAttributes: [String: String]
  ) {
    self.stylesheetHref = stylesheetHref
    self.styleSheetIndex = styleSheetIndex
    self.ruleIndexPath = ruleIndexPath
    self.selectorText = selectorText
    self.specificity = specificity
    self.ownerNodeAttributes = ownerNodeAttributes
  }
}

public enum WebPreviewStyleUncertainty: String, Sendable, CaseIterable {
  case layer
  case scope
  case containerQuery
  case unknownGroup
  case adoptedSheet
  case unreadableSheet
  case nestedSelector
  case complexSelector
  case importantConflict
}

public struct WebPreviewPropertyWinner: Equatable, Sendable {
  public let property: String
  public let declaredValue: String
  public let isInline: Bool
  public let isImportant: Bool
  public let rule: WebPreviewCSSRuleLocator?
  public let uncertainties: Set<WebPreviewStyleUncertainty>

  public init(
    property: String,
    declaredValue: String,
    isInline: Bool,
    isImportant: Bool,
    rule: WebPreviewCSSRuleLocator?,
    uncertainties: Set<WebPreviewStyleUncertainty>
  ) {
    self.property = property
    self.declaredValue = declaredValue
    self.isInline = isInline
    self.isImportant = isImportant
    self.rule = rule
    self.uncertainties = uncertainties
  }

  /// True when this winner can be considered for a direct file edit.
  public var isProvable: Bool {
    !isInline && rule != nil && uncertainties.isEmpty
  }
}

/// A proven Tier-1 write target for one CSS property.
public struct WebPreviewDirectStyleTarget: Equatable, Sendable {
  public let filePath: String
  /// Rule position inside the CSS document — the file itself, or the inline
  /// `<style>` block addressed by `embeddedStyleBlockIndex`.
  public let ruleIndexPath: [Int]
  public var contentSHA256: String
  /// When set, `filePath` is an HTML file and the rule lives in its
  /// N-th inline `<style>` block.
  public var embeddedStyleBlockIndex: Int?

  public init(
    filePath: String,
    ruleIndexPath: [Int],
    contentSHA256: String,
    embeddedStyleBlockIndex: Int? = nil
  ) {
    self.filePath = filePath
    self.ruleIndexPath = ruleIndexPath
    self.contentSHA256 = contentSHA256
    self.embeddedStyleBlockIndex = embeddedStyleBlockIndex
  }
}

/// How an edited style property persists to code.
public enum WebPreviewStyleEditTier: Equatable, Sendable {
  case direct(WebPreviewDirectStyleTarget)
  case agent
}

public struct WebPreviewStyleProvenance: Equatable, Sendable {
  public let winners: [WebPreviewPropertyWinner]
  public let unreadableSheetHrefs: [String]
  public let hasAdoptedSheets: Bool
  /// Every property name declared by any matched (or possibly-matched) rule,
  /// longhands included — used to keep insertions clear of shorthand
  /// interference.
  public let declaredPropertyNames: [String]
  /// Property names declared on the element's `style` attribute.
  public let inlinePropertyNames: [String]
  /// The plainest matching rule (no flags, no conditions): where a
  /// brand-new declaration may be inserted.
  public let anchorRule: WebPreviewCSSRuleLocator?

  public init(
    winners: [WebPreviewPropertyWinner],
    unreadableSheetHrefs: [String],
    hasAdoptedSheets: Bool,
    declaredPropertyNames: [String] = [],
    inlinePropertyNames: [String] = [],
    anchorRule: WebPreviewCSSRuleLocator? = nil
  ) {
    self.winners = winners
    self.unreadableSheetHrefs = unreadableSheetHrefs
    self.hasAdoptedSheets = hasAdoptedSheets
    self.declaredPropertyNames = declaredPropertyNames
    self.inlinePropertyNames = inlinePropertyNames
    self.anchorRule = anchorRule
  }

  public func winner(for property: String) -> WebPreviewPropertyWinner? {
    winners.first { $0.property == property }
  }

  /// Parses the dictionary returned by the in-page provenance script.
  public static func parse(_ body: Any?) -> WebPreviewStyleProvenance? {
    guard let dictionary = body as? [String: Any],
          dictionary["ok"] as? Bool == true else {
      return nil
    }

    let unreadable = dictionary["unreadableSheets"] as? [String] ?? []
    let hasAdopted = dictionary["hasAdoptedSheets"] as? Bool ?? false
    let rawWinners = dictionary["winners"] as? [[String: Any]] ?? []

    let winners = rawWinners.compactMap { raw -> WebPreviewPropertyWinner? in
      guard let property = raw["property"] as? String,
            let declaredValue = raw["declaredValue"] as? String else {
        return nil
      }

      let flags = (raw["flags"] as? [String] ?? [])
        .compactMap(WebPreviewStyleUncertainty.init(rawValue:))

      return WebPreviewPropertyWinner(
        property: property,
        declaredValue: declaredValue,
        isInline: raw["isInline"] as? Bool ?? false,
        isImportant: raw["isImportant"] as? Bool ?? false,
        rule: parseRuleLocator(raw["rule"]),
        uncertainties: Set(flags)
      )
    }

    return WebPreviewStyleProvenance(
      winners: winners,
      unreadableSheetHrefs: unreadable,
      hasAdoptedSheets: hasAdopted,
      declaredPropertyNames: dictionary["declaredNames"] as? [String] ?? [],
      inlinePropertyNames: dictionary["inlineNames"] as? [String] ?? [],
      anchorRule: parseRuleLocator(dictionary["anchor"])
    )
  }

  private static func parseRuleLocator(_ value: Any?) -> WebPreviewCSSRuleLocator? {
    guard let rawRule = value as? [String: Any],
          let selectorText = rawRule["selectorText"] as? String,
          let ruleIndexPath = intArray(rawRule["ruleIndexPath"]),
          let styleSheetIndex = intValue(rawRule["styleSheetIndex"]) else {
      return nil
    }
    return WebPreviewCSSRuleLocator(
      stylesheetHref: rawRule["stylesheetHref"] as? String,
      styleSheetIndex: styleSheetIndex,
      ruleIndexPath: ruleIndexPath,
      selectorText: selectorText,
      specificity: intArray(rawRule["specificity"]) ?? [],
      ownerNodeAttributes: rawRule["ownerNodeAttributes"] as? [String: String] ?? [:]
    )
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let intValue = value as? Int { return intValue }
    if let doubleValue = value as? Double { return Int(doubleValue) }
    if let number = value as? NSNumber { return number.intValue }
    return nil
  }

  private static func intArray(_ value: Any?) -> [Int]? {
    guard let array = value as? [Any] else { return nil }
    let ints = array.compactMap(intValue)
    return ints.count == array.count ? ints : nil
  }
}
