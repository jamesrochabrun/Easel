//
//  WebPreviewElementSourceHint.swift
//  EaselWebInspector
//
//  Best-effort source locations that framework dev builds already expose
//  (Svelte __svelte_meta, Vue inspector attrs, React fibers, generic
//  data-source attributes). Zero-touch: read-only, never used for direct
//  writes — they anchor agent prompts and the inspector rail.
//

import Foundation

public struct WebPreviewElementSourceHint: Equatable, Sendable {
  public enum Kind: String, Sendable {
    case svelteMeta
    case vueInspector
    case reactDebugSource
    case reactOwnerChain
    case genericAttribute
  }

  public let kind: Kind
  public let file: String?
  public let line: Int?
  public let column: Int?
  public let detail: String?

  public init(
    kind: Kind,
    file: String?,
    line: Int?,
    column: Int?,
    detail: String?
  ) {
    self.kind = kind
    self.file = file
    self.line = line
    self.column = column
    self.detail = detail
  }

  public var frameworkLabel: String {
    switch kind {
    case .svelteMeta: "svelte"
    case .vueInspector: "vue"
    case .reactDebugSource, .reactOwnerChain: "react"
    case .genericAttribute: "source attribute"
    }
  }

  /// One-line rendering for agent prompts and the rail.
  public var promptLine: String {
    if let file {
      var location = file
      if let line {
        location += ":\(line)"
        if let column {
          location += ":\(column)"
        }
      }
      return "\(location) (\(frameworkLabel))"
    }
    if let detail {
      return "\(detail) (\(frameworkLabel))"
    }
    return frameworkLabel
  }

  /// Parses the payload returned by the source-hint script.
  public static func parse(_ body: Any?) -> [WebPreviewElementSourceHint] {
    guard let dictionary = body as? [String: Any],
          dictionary["ok"] as? Bool == true,
          let rawHints = dictionary["hints"] as? [[String: Any]] else {
      return []
    }

    return rawHints.compactMap { raw in
      guard let kind = (raw["kind"] as? String).flatMap(Kind.init(rawValue:)) else {
        return nil
      }
      return WebPreviewElementSourceHint(
        kind: kind,
        file: nonEmpty(raw["file"] as? String),
        line: positiveInt(raw["line"]),
        column: positiveInt(raw["column"]),
        detail: nonEmpty(raw["detail"] as? String)
      )
    }
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  private static func positiveInt(_ value: Any?) -> Int? {
    let intValue: Int?
    if let value = value as? Int {
      intValue = value
    } else if let value = value as? Double {
      intValue = Int(value)
    } else if let value = value as? NSNumber {
      intValue = value.intValue
    } else {
      intValue = nil
    }
    guard let intValue, intValue > 0 else { return nil }
    return intValue
  }
}
