//
//  EaselDesignSystemCatalog.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemCatalog: Codable, Equatable, Sendable {
  /// Shared disclaimer for catalogs parsed locally from a `.fig` file. Surfaced
  /// in the native browser, the generated `index.html`, and the manifest summary
  /// so the lossy nature of local parsing is never hidden.
  public static let localFigDisclaimer =
    "Parsed locally from .fig. Use as reference. Not a 1:1 imported design system."

  public let name: String
  public let summary: String
  public let generatedAt: Date?
  public let componentGroups: [EaselDesignSystemComponentGroup]

  // Tokens-first reference fields. All optional so existing `catalog.json`
  // files, the built-in presets, and prior tests decode/compile unchanged.
  public let title: String?
  public let isReference: Bool
  public let disclaimer: String?
  public let tokens: EaselDesignSystemTokenSet?
  public let componentFamilies: [EaselDesignSystemComponentFamily]?
  public let examples: [EaselDesignSystemExample]?
  public let assets: [EaselDesignSystemAsset]?
  public let heroThumbnailPath: String?
  public let sourceDiagnostics: EaselDesignSystemSourceDiagnostics?

  public init(
    name: String,
    summary: String,
    generatedAt: Date?,
    componentGroups: [EaselDesignSystemComponentGroup],
    title: String? = nil,
    isReference: Bool = false,
    disclaimer: String? = nil,
    tokens: EaselDesignSystemTokenSet? = nil,
    componentFamilies: [EaselDesignSystemComponentFamily]? = nil,
    examples: [EaselDesignSystemExample]? = nil,
    assets: [EaselDesignSystemAsset]? = nil,
    heroThumbnailPath: String? = nil,
    sourceDiagnostics: EaselDesignSystemSourceDiagnostics? = nil
  ) {
    self.name = name
    self.summary = summary
    self.generatedAt = generatedAt
    self.componentGroups = componentGroups
    self.title = title
    self.isReference = isReference
    self.disclaimer = disclaimer
    self.tokens = tokens
    self.componentFamilies = componentFamilies
    self.examples = examples
    self.assets = assets
    self.heroThumbnailPath = heroThumbnailPath
    self.sourceDiagnostics = sourceDiagnostics
  }

  /// `true` when the catalog carries any visual/token reference content worth
  /// rendering tokens-first (vs. an empty placeholder or a text-only preset).
  public var hasReferenceContent: Bool {
    let tokenCount = tokens.map {
      $0.colors.count + $0.typography.count + $0.spacing.count + $0.radii.count + $0.effects.count
    } ?? 0
    return tokenCount > 0
      || (componentFamilies?.isEmpty == false)
      || (examples?.isEmpty == false)
      || (assets?.isEmpty == false)
  }

  public static func placeholder(for profile: EaselDesignSystemProfile) -> EaselDesignSystemCatalog {
    EaselDesignSystemCatalog(
      name: profile.name,
      summary: "The generated catalog will appear after Codex finishes creating this design system.",
      generatedAt: nil,
      componentGroups: []
    )
  }

  private enum CodingKeys: String, CodingKey {
    case name
    case summary
    case generatedAt
    case componentGroups
    case title
    case isReference
    case disclaimer
    case tokens
    case componentFamilies
    case examples
    case assets
    case heroThumbnailPath
    case sourceDiagnostics
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    summary = try container.decode(String.self, forKey: .summary)
    generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
    componentGroups = try container.decodeIfPresent([EaselDesignSystemComponentGroup].self, forKey: .componentGroups) ?? []
    title = try container.decodeIfPresent(String.self, forKey: .title)
    isReference = try container.decodeIfPresent(Bool.self, forKey: .isReference) ?? false
    disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
    tokens = try container.decodeIfPresent(EaselDesignSystemTokenSet.self, forKey: .tokens)
    componentFamilies = try container.decodeIfPresent([EaselDesignSystemComponentFamily].self, forKey: .componentFamilies)
    examples = try container.decodeIfPresent([EaselDesignSystemExample].self, forKey: .examples)
    assets = try container.decodeIfPresent([EaselDesignSystemAsset].self, forKey: .assets)
    heroThumbnailPath = try container.decodeIfPresent(String.self, forKey: .heroThumbnailPath)
    sourceDiagnostics = try container.decodeIfPresent(EaselDesignSystemSourceDiagnostics.self, forKey: .sourceDiagnostics)
  }
}
