//
//  EaselDesignSystemCatalog.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemCatalog: Codable, Equatable, Sendable {
  public let schemaVersion: Int?
  public let name: String
  public let summary: String
  public let generatedAt: Date?

  // MARK: - schemaVersion 3 design tokens (the source of truth the canvas renders)

  public let colors: [EaselDesignColorToken]
  public let typography: EaselDesignTypography?
  public let spacing: [EaselDesignScaleToken]
  public let radii: [EaselDesignScaleToken]
  public let elevation: [EaselDesignElevationToken]
  public let states: [EaselDesignStateToken]
  public let icons: [EaselDesignIconToken]
  public let components: [EaselDesignSystemComponentSpec]

  // MARK: - Legacy schema (presets + back-compat for older catalogs)

  public let sections: [EaselDesignSystemCatalogSection]
  public let componentGroups: [EaselDesignSystemComponentGroup]

  public init(
    schemaVersion: Int? = nil,
    name: String,
    summary: String,
    generatedAt: Date?,
    colors: [EaselDesignColorToken] = [],
    typography: EaselDesignTypography? = nil,
    spacing: [EaselDesignScaleToken] = [],
    radii: [EaselDesignScaleToken] = [],
    elevation: [EaselDesignElevationToken] = [],
    states: [EaselDesignStateToken] = [],
    icons: [EaselDesignIconToken] = [],
    components: [EaselDesignSystemComponentSpec] = [],
    sections: [EaselDesignSystemCatalogSection] = [],
    componentGroups: [EaselDesignSystemComponentGroup] = []
  ) {
    self.schemaVersion = schemaVersion
    self.name = name
    self.summary = summary
    self.generatedAt = generatedAt
    self.colors = colors
    self.typography = typography
    self.spacing = spacing
    self.radii = radii
    self.elevation = elevation
    self.states = states
    self.icons = icons
    self.components = components
    self.sections = sections
    self.componentGroups = componentGroups.isEmpty ? sections.flatMap(\.groups) : componentGroups
  }

  /// True when the catalog carries any schemaVersion 3 design tokens.
  public var hasTokenContent: Bool {
    !colors.isEmpty
      || !(typography?.styles.isEmpty ?? true)
      || !spacing.isEmpty
      || !radii.isEmpty
      || !elevation.isEmpty
      || !states.isEmpty
      || !icons.isEmpty
      || !components.isEmpty
  }

  public var displaySections: [EaselDesignSystemCatalogSection] {
    if !sections.isEmpty {
      return sections
    }

    let groups = browsableGroups
    guard !groups.isEmpty else { return [] }
    return [
      EaselDesignSystemCatalogSection(
        id: "components",
        title: "Catalog",
        summary: "Primitives and components in this design system.",
        groups: groups
      )
    ]
  }

  /// Flat list of groups the in-app browser renders. When the catalog carries
  /// design tokens, each token category and component is synthesized into a
  /// browsable group; otherwise it falls back to the legacy component groups.
  public var browsableGroups: [EaselDesignSystemComponentGroup] {
    guard hasTokenContent else {
      return componentGroups
    }

    var groups: [EaselDesignSystemComponentGroup] = []

    if !colors.isEmpty {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: "colors",
          title: "Colors",
          summary: "\(colors.count) color \(colors.count == 1 ? "token" : "tokens")",
          previewPath: nil,
          items: colors.map { color in
            EaselDesignSystemComponentItem(
              id: color.id ?? "color-\(EaselDesignSystemComponentSpec.slug(color.name))",
              title: color.name,
              summary: [color.group, color.value].compactMap { $0 }.joined(separator: " · ")
            )
          }
        )
      )
    }

    if let typography, !typography.styles.isEmpty {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: "typography",
          title: "Typography",
          summary: "\(typography.styles.count) type \(typography.styles.count == 1 ? "style" : "styles")",
          previewPath: nil,
          items: typography.styles.map { style in
            EaselDesignSystemComponentItem(
              id: style.id ?? "type-\(EaselDesignSystemComponentSpec.slug(style.name))",
              title: style.name,
              summary: Self.typeStyleSummary(style)
            )
          }
        )
      )
    }

    if !spacing.isEmpty {
      groups.append(Self.scaleGroup(id: "spacing", title: "Spacing", tokens: spacing))
    }
    if !radii.isEmpty {
      groups.append(Self.scaleGroup(id: "radii", title: "Radii", tokens: radii))
    }

    if !elevation.isEmpty {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: "elevation",
          title: "Elevation",
          summary: "\(elevation.count) shadow \(elevation.count == 1 ? "level" : "levels")",
          previewPath: nil,
          items: elevation.map { level in
            EaselDesignSystemComponentItem(
              id: level.id ?? "elevation-\(EaselDesignSystemComponentSpec.slug(level.name))",
              title: level.name,
              summary: level.usage ?? level.shadow
            )
          }
        )
      )
    }

    if !states.isEmpty {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: "states",
          title: "States",
          summary: "\(states.count) interaction \(states.count == 1 ? "state" : "states")",
          previewPath: nil,
          items: states.map { state in
            EaselDesignSystemComponentItem(
              id: state.id ?? "state-\(EaselDesignSystemComponentSpec.slug(state.name))",
              title: state.name,
              summary: state.description ?? ""
            )
          }
        )
      )
    }

    if !icons.isEmpty {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: "icons",
          title: "Iconography",
          summary: "\(icons.count) \(icons.count == 1 ? "icon" : "icons")",
          previewPath: nil,
          items: icons.map { icon in
            EaselDesignSystemComponentItem(
              id: icon.id ?? "icon-\(EaselDesignSystemComponentSpec.slug(icon.name))",
              title: icon.name,
              summary: (icon.keywords ?? []).joined(separator: ", ")
            )
          }
        )
      )
    }

    for component in components {
      groups.append(
        EaselDesignSystemComponentGroup(
          id: component.id,
          title: component.name,
          summary: component.summary ?? "\(component.variants.count) \(component.variants.count == 1 ? "variant" : "variants")",
          previewPath: nil,
          items: component.variants.map { variant in
            EaselDesignSystemComponentItem(
              id: "\(component.id)-\(EaselDesignSystemComponentSpec.slug(variant.name))",
              title: variant.name,
              summary: variant.label ?? ""
            )
          }
        )
      )
    }

    return groups
  }

  public static func placeholder(for profile: EaselDesignSystemProfile) -> EaselDesignSystemCatalog {
    EaselDesignSystemCatalog(
      schemaVersion: 3,
      name: profile.name,
      summary: "The generated catalog will appear after Codex finishes creating this design system.",
      generatedAt: nil
    )
  }

  private static func scaleGroup(
    id: String,
    title: String,
    tokens: [EaselDesignScaleToken]
  ) -> EaselDesignSystemComponentGroup {
    EaselDesignSystemComponentGroup(
      id: id,
      title: title,
      summary: "\(tokens.count) \(tokens.count == 1 ? "step" : "steps")",
      previewPath: nil,
      items: tokens.map { token in
        EaselDesignSystemComponentItem(
          id: token.id ?? "\(id)-\(EaselDesignSystemComponentSpec.slug(token.name))",
          title: token.name,
          summary: "\(formatNumber(token.value))px"
        )
      }
    )
  }

  private static func typeStyleSummary(_ style: EaselDesignTypeStyle) -> String {
    var parts: [String] = []
    if let size = style.size { parts.append("\(formatNumber(size))px") }
    if let weight = style.weight { parts.append("\(weight)") }
    if let lineHeight = style.lineHeight { parts.append("LH \(formatNumber(lineHeight))") }
    return parts.joined(separator: " · ")
  }

  private static func formatNumber(_ value: Double) -> String {
    if value == value.rounded() {
      return String(Int(value))
    }
    return String(value)
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion
    case name
    case summary
    case generatedAt
    case colors
    case typography
    case spacing
    case radii
    case elevation
    case states
    case icons
    case components
    case sections
    case componentGroups
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
    name = try container.decode(String.self, forKey: .name)
    summary = try container.decode(String.self, forKey: .summary)
    generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)

    colors = try container.decodeIfPresent([EaselDesignColorToken].self, forKey: .colors) ?? []
    typography = try container.decodeIfPresent(EaselDesignTypography.self, forKey: .typography)
    spacing = try container.decodeIfPresent([EaselDesignScaleToken].self, forKey: .spacing) ?? []
    radii = try container.decodeIfPresent([EaselDesignScaleToken].self, forKey: .radii) ?? []
    elevation = try container.decodeIfPresent([EaselDesignElevationToken].self, forKey: .elevation) ?? []
    states = try container.decodeIfPresent([EaselDesignStateToken].self, forKey: .states) ?? []
    icons = try container.decodeIfPresent([EaselDesignIconToken].self, forKey: .icons) ?? []
    components = try container.decodeIfPresent([EaselDesignSystemComponentSpec].self, forKey: .components) ?? []

    sections = try container.decodeIfPresent(
      [EaselDesignSystemCatalogSection].self,
      forKey: .sections
    ) ?? []

    let decodedGroups = try container.decodeIfPresent(
      [EaselDesignSystemComponentGroup].self,
      forKey: .componentGroups
    ) ?? []
    componentGroups = decodedGroups.isEmpty ? sections.flatMap(\.groups) : decodedGroups
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
    try container.encode(name, forKey: .name)
    try container.encode(summary, forKey: .summary)
    try container.encodeIfPresent(generatedAt, forKey: .generatedAt)

    if !colors.isEmpty { try container.encode(colors, forKey: .colors) }
    if let typography, !(typography.fonts.isEmpty && typography.styles.isEmpty) {
      try container.encode(typography, forKey: .typography)
    }
    if !spacing.isEmpty { try container.encode(spacing, forKey: .spacing) }
    if !radii.isEmpty { try container.encode(radii, forKey: .radii) }
    if !elevation.isEmpty { try container.encode(elevation, forKey: .elevation) }
    if !states.isEmpty { try container.encode(states, forKey: .states) }
    if !icons.isEmpty { try container.encode(icons, forKey: .icons) }
    if !components.isEmpty { try container.encode(components, forKey: .components) }

    if !sections.isEmpty { try container.encode(sections, forKey: .sections) }
    if !componentGroups.isEmpty { try container.encode(componentGroups, forKey: .componentGroups) }
  }
}
