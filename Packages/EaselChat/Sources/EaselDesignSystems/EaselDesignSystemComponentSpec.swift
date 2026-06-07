//
//  EaselDesignSystemComponentSpec.swift
//  EaselDesignSystems
//
//  A basic UI component described purely by token values so the app-owned
//  `index.html` can render it live (variants + states) using the system's
//  own colors, radii, and shadows.
//

import Foundation

/// Per-state visual overrides for a component variant.
public struct EaselDesignSystemComponentVariantState: Codable, Equatable, Sendable {
  public let background: String?
  public let foreground: String?
  public let border: String?
  public let shadow: String?

  public init(
    background: String? = nil,
    foreground: String? = nil,
    border: String? = nil,
    shadow: String? = nil
  ) {
    self.background = background
    self.foreground = foreground
    self.border = border
    self.shadow = shadow
  }
}

/// A single component variant. The fields are a superset across component
/// kinds; each renderer reads only what it needs:
/// - button / badge: label, background, foreground, border, radius, shadow
/// - segmented: options, selectedIndex, background, selectedBackground, foreground, selectedForeground
/// - textfield / textarea: label, placeholder, background, foreground, border, focusBorder, radius
/// - toggle / checkbox / radio: checked, onColor, offColor
public struct EaselDesignSystemComponentVariant: Codable, Equatable, Sendable {
  public let name: String
  public let label: String?
  public let placeholder: String?
  public let background: String?
  public let foreground: String?
  public let border: String?
  public let focusBorder: String?
  public let radius: Double?
  public let shadow: String?
  public let options: [String]?
  public let selectedIndex: Int?
  public let selectedBackground: String?
  public let selectedForeground: String?
  public let checked: Bool?
  public let onColor: String?
  public let offColor: String?
  /// Optional per-state overrides keyed by state name (e.g. "hover", "active", "focus", "disabled").
  public let states: [String: EaselDesignSystemComponentVariantState]?

  public init(
    name: String,
    label: String? = nil,
    placeholder: String? = nil,
    background: String? = nil,
    foreground: String? = nil,
    border: String? = nil,
    focusBorder: String? = nil,
    radius: Double? = nil,
    shadow: String? = nil,
    options: [String]? = nil,
    selectedIndex: Int? = nil,
    selectedBackground: String? = nil,
    selectedForeground: String? = nil,
    checked: Bool? = nil,
    onColor: String? = nil,
    offColor: String? = nil,
    states: [String: EaselDesignSystemComponentVariantState]? = nil
  ) {
    self.name = name
    self.label = label
    self.placeholder = placeholder
    self.background = background
    self.foreground = foreground
    self.border = border
    self.focusBorder = focusBorder
    self.radius = radius
    self.shadow = shadow
    self.options = options
    self.selectedIndex = selectedIndex
    self.selectedBackground = selectedBackground
    self.selectedForeground = selectedForeground
    self.checked = checked
    self.onColor = onColor
    self.offColor = offColor
    self.states = states
  }
}

/// A basic component grouping (e.g. Buttons, Segmented control). `kind`
/// selects the renderer; supported kinds:
/// `button | segmented | textfield | textarea | toggle | checkbox | radio | badge`.
public struct EaselDesignSystemComponentSpec: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let kind: String
  public let name: String
  public let summary: String?
  public let variants: [EaselDesignSystemComponentVariant]

  public init(
    id: String,
    kind: String,
    name: String,
    summary: String? = nil,
    variants: [EaselDesignSystemComponentVariant] = []
  ) {
    self.id = id
    self.kind = kind
    self.name = name
    self.summary = summary
    self.variants = variants
  }

  enum CodingKeys: String, CodingKey {
    case id
    case kind
    case name
    case summary
    case variants
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    let kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "button"
    let fallbackID = EaselDesignSystemComponentSpec.slug(name).isEmpty ? kind : EaselDesignSystemComponentSpec.slug(name)
    self.name = name
    self.kind = kind
    id = try container.decodeIfPresent(String.self, forKey: .id) ?? fallbackID
    summary = try container.decodeIfPresent(String.self, forKey: .summary)
    variants = try container.decodeIfPresent([EaselDesignSystemComponentVariant].self, forKey: .variants) ?? []
  }

  static func slug(_ value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let allowed = CharacterSet.alphanumerics
    var result = ""
    var previousWasSeparator = false
    for scalar in folded.unicodeScalars {
      if allowed.contains(scalar) {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if !previousWasSeparator {
        result.append("-")
        previousWasSeparator = true
      }
    }
    return result.trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
  }
}
