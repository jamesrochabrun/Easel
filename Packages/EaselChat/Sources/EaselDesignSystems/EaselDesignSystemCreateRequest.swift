//
//  EaselDesignSystemCreateRequest.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemCreateRequest: Equatable, Sendable {
  /// How the design system's canonical `DESIGN.md` is sourced. Every path
  /// produces a spec-compliant `DESIGN.md` plus the derived `catalog.json`.
  public enum Source: Equatable, Sendable {
    /// Existing behavior: scaffold from a blurb plus optional code/.fig/assets.
    /// A `.fig` emits a rich DESIGN.md during import.
    case resources
    /// Import and normalize an existing `DESIGN.md` file.
    case designMarkdown(URL)
    /// Import and normalize pasted `DESIGN.md` text.
    case designMarkdownText(String)
    /// Generate a DESIGN.md from a natural-language prompt via an LLM.
    case prompt(String)
  }

  public let blurb: String
  public let sourceLinks: [String]
  public let codeSourceURLs: [URL]
  public let figFileURLs: [URL]
  public let figImportMode: EaselDesignSystemFigImportMode
  public let assetURLs: [URL]
  public let notes: String
  public let source: Source
  /// Optional explicit name. When provided it names the design system and is
  /// written into the canonical `DESIGN.md`'s `name:` field; otherwise the name
  /// is derived from the blurb / imported document / generated document.
  public let nameHint: String?

  public init(
    blurb: String,
    sourceLinks: [String],
    codeSourceURLs: [URL],
    figFileURLs: [URL],
    figImportMode: EaselDesignSystemFigImportMode = .extractCatalog,
    assetURLs: [URL],
    notes: String,
    source: Source = .resources,
    nameHint: String? = nil
  ) {
    self.blurb = blurb
    self.sourceLinks = sourceLinks
    self.codeSourceURLs = codeSourceURLs
    self.figFileURLs = figFileURLs
    self.figImportMode = figImportMode
    self.assetURLs = assetURLs
    self.notes = notes
    self.source = source
    self.nameHint = nameHint
  }
}
