//
//  EaselDesignSystemExampleIndexing.swift
//  EaselChat
//

import Foundation

public enum EaselDesignSystemExampleIndexing {
  public static func isHighSignalExample(
    title: String,
    sourcePage: String?,
    preview: EaselDesignSystemPreviewScene? = nil
  ) -> Bool {
    let titleWords = words(in: title)
    guard !titleWords.isEmpty else { return false }

    let sourceWords = words(in: sourcePage ?? "")
    if isFoundationOnly(titleWords) || isFoundationOnly(sourceWords) {
      return false
    }

    let titleHasStructuralTerm = containsAny(structuralReferenceTerms, in: titleWords)
    let hasStructuralTerm = titleHasStructuralTerm || containsAny(structuralReferenceTerms, in: sourceWords)
    let titleHasProductTerm = containsAny(productReferenceTerms, in: titleWords)
    let hasProductTerm = titleHasProductTerm || containsAny(productReferenceTerms, in: sourceWords)
    let titleHasComponentTerm = containsAny(componentDocumentationTerms, in: titleWords)

    if titleHasComponentTerm, !titleHasProductTerm {
      return false
    }

    if isDocumentationSource(sourceWords), !hasStructuralTerm {
      return false
    }

    if hasStructuralTerm || hasProductTerm {
      return true
    }

    if isExampleSource(sourceWords), !titleHasComponentTerm {
      return preview == nil || isScreenLikePreview(preview)
    }

    return false
  }

  private static let structuralReferenceTerms = [
    "flow",
    "layout",
    "mockup",
    "prototype",
    "screen",
    "template",
    "wireframe",
  ]

  private static let productReferenceTerms = [
    "account",
    "analytics",
    "booking",
    "calendar",
    "cart",
    "chat",
    "checkout",
    "dashboard",
    "detail",
    "editor",
    "feed",
    "inbox",
    "landing",
    "listing",
    "login",
    "map",
    "message",
    "notification",
    "onboarding",
    "order",
    "payment",
    "pricing",
    "product",
    "profile",
    "registration",
    "report",
    "result",
    "search",
    "setting",
    "signup",
    "timeline",
    "wizard",
    "sign in",
    "sign up",
    "empty state",
    "error state",
  ]

  private static let componentDocumentationTerms = [
    "accordion",
    "action sheet",
    "alert",
    "avatar",
    "badge",
    "banner",
    "breadcrumb",
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

  private static let foundationWords: Set<String> = [
    "asset",
    "brand",
    "color",
    "cover",
    "effect",
    "foundation",
    "icon",
    "iconography",
    "logo",
    "radius",
    "readme",
    "shadow",
    "spacing",
    "style",
    "token",
    "typography",
    "welcome",
  ]

  private static let documentationSourceTerms = [
    "component",
    "design system",
    "foundation",
    "guideline",
    "library",
    "style guide",
    "token",
  ]

  private static let exampleSourceTerms = [
    "example",
    "flow",
    "layout",
    "product",
    "screen",
    "template",
  ]

  private static func isFoundationOnly(_ words: [String]) -> Bool {
    !words.isEmpty && words.allSatisfy { foundationWords.contains($0) }
  }

  private static func isDocumentationSource(_ words: [String]) -> Bool {
    containsAny(documentationSourceTerms, in: words)
  }

  private static func isExampleSource(_ words: [String]) -> Bool {
    containsAny(exampleSourceTerms, in: words)
  }

  private static func isScreenLikePreview(_ scene: EaselDesignSystemPreviewScene?) -> Bool {
    guard let scene else { return false }
    let longSide = max(scene.width, scene.height)
    let shortSide = min(scene.width, scene.height)
    guard shortSide >= 120, longSide >= 160 else { return false }
    return longSide / shortSide <= 3.5
  }

  private static func words(in value: String) -> [String] {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .split { !$0.isLetter && !$0.isNumber }
      .map { singularized(String($0)) }
  }

  private static func containsAny(_ terms: [String], in words: [String]) -> Bool {
    terms.contains { term in
      let termWords = self.words(in: term)
      return !termWords.isEmpty && contains(termWords, in: words)
    }
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

public extension EaselDesignSystemExample {
  var isHighSignalIndexEntry: Bool {
    EaselDesignSystemExampleIndexing.isHighSignalExample(
      title: title,
      sourcePage: sourcePage,
      preview: preview
    )
  }
}
