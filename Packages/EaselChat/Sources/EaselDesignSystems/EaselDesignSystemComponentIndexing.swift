//
//  EaselDesignSystemComponentIndexing.swift
//  EaselChat
//

import Foundation

public enum EaselDesignSystemComponentIndexing {
  public static func isHighSignalFamily(
    title: String,
    category: String,
    variantCount: Int,
    variantProperties: [EaselDesignSystemVariantProperty]
  ) -> Bool {
    let title = normalized(title)
    guard !title.isEmpty, !isVariantOnlyTitle(title) else { return false }

    if containsReusableComponentTerm(title) {
      return true
    }

    guard isStrongComponentCategory(category) else { return false }
    return variantCount > 1 || !variantProperties.isEmpty
  }

  private static let reusableComponentTerms = [
    "accordion",
    "alert",
    "avatar",
    "badge",
    "banner",
    "button",
    "card",
    "carousel",
    "checkbox",
    "chip",
    "context menu",
    "dialog",
    "drawer",
    "dropdown",
    "field",
    "input",
    "list",
    "menu",
    "modal",
    "nav",
    "navbar",
    "page control",
    "pagination",
    "popover",
    "pop up",
    "popup",
    "progress",
    "radio",
    "select",
    "segmented",
    "sheet",
    "slider",
    "stepper",
    "switch",
    "tab",
    "table",
    "toast",
    "toggle",
    "tooltip",
  ]

  private static let strongComponentCategories: Set<String> = [
    "buttons",
    "cards",
    "indicators",
    "inputs",
    "navigation",
    "overlays",
  ]

  private static func containsReusableComponentTerm(_ title: String) -> Bool {
    let titleWords = words(in: title)
    return reusableComponentTerms.contains { term in
      let termWords = words(in: term)
      return !termWords.isEmpty && contains(termWords, in: titleWords)
    }
  }

  private static func isStrongComponentCategory(_ category: String) -> Bool {
    strongComponentCategories.contains(normalized(category))
  }

  private static func isVariantOnlyTitle(_ title: String) -> Bool {
    let segments = title.split(separator: ",")
    guard !segments.isEmpty else { return false }

    return segments.allSatisfy { segment in
      let parts = segment.split(separator: "=", maxSplits: 1)
      guard parts.count == 2 else { return false }
      let propertyName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
      let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
      return !propertyName.isEmpty && !value.isEmpty
    }
  }

  private static func normalized(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private static func words(in value: String) -> [String] {
    normalized(value)
      .split { !$0.isLetter && !$0.isNumber }
      .map { singularized(String($0)) }
  }

  private static func contains(_ needle: [String], in haystack: [String]) -> Bool {
    guard needle.count <= haystack.count else { return false }
    if needle.count == 1 {
      return haystack.contains(needle[0])
    }

    for startIndex in haystack.indices {
      let endIndex = startIndex + needle.count
      guard endIndex <= haystack.count else { break }
      if Array(haystack[startIndex..<endIndex]) == needle {
        return true
      }
    }
    return false
  }

  private static func singularized(_ word: String) -> String {
    guard word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") else {
      return word
    }
    return String(word.dropLast())
  }
}

public extension EaselDesignSystemComponentFamily {
  var isHighSignalIndexEntry: Bool {
    EaselDesignSystemComponentIndexing.isHighSignalFamily(
      title: title,
      category: category,
      variantCount: variantCount,
      variantProperties: variantProperties
    )
  }
}
