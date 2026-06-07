//
//  EaselProjectModels.swift
//  EaselChat
//

import Foundation
import EaselDesignSystems

public enum EaselProjectKind: String, CaseIterable, Codable, Identifiable, Sendable {
  case prototype
  case slideDeck

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .prototype:
      return "Prototype"
    case .slideDeck:
      return "Slide deck"
    }
  }

  var creationTitle: String {
    switch self {
    case .prototype:
      return "New prototype"
    case .slideDeck:
      return "New slide deck"
    }
  }

  var placeholderName: String {
    switch self {
    case .prototype:
      return "Project name"
    case .slideDeck:
      return "Deck name"
    }
  }

  var systemImage: String {
    switch self {
    case .prototype:
      return "rectangle.inset.filled"
    case .slideDeck:
      return "rectangle.on.rectangle"
    }
  }
}

public enum EaselProjectFidelity: String, CaseIterable, Codable, Identifiable, Sendable {
  case wireframe
  case highFidelity

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .wireframe:
      return "Wireframe"
    case .highFidelity:
      return "High fidelity"
    }
  }

  var pickerDescription: String {
    switch self {
    case .wireframe:
      return "Structure and flow before visual polish."
    case .highFidelity:
      return "Polished visuals with assets and states."
    }
  }

  var agentGuidance: String {
    switch self {
    case .wireframe:
      return "Prioritize structure, screen flow, hierarchy, navigation, grayscale placeholders, and minimal styling. Avoid final polish, heavy imagery, and decorative motion unless requested."
    case .highFidelity:
      return "Prioritize polished UI, design-system usage, refined spacing, typography, color, realistic local assets, responsive states, and restrained motion."
    }
  }

}

public struct EaselProjectCreateRequest: Sendable, Equatable {
  public let name: String
  public let kind: EaselProjectKind
  public let designSystems: [EaselDesignSystemChoice]
  public let fidelity: EaselProjectFidelity

  public var designSystem: EaselDesignSystemChoice {
    designSystems.first ?? .preset(.none)
  }

  public init(
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemChoice,
    fidelity: EaselProjectFidelity
  ) {
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence([designSystem])
    self.fidelity = fidelity
  }

  public init(
    name: String,
    kind: EaselProjectKind,
    designSystems: [EaselDesignSystemChoice],
    fidelity: EaselProjectFidelity
  ) {
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence(designSystems)
    self.fidelity = fidelity
  }

  public init(
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemPreset,
    fidelity: EaselProjectFidelity
  ) {
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence([.preset(designSystem)])
    self.fidelity = fidelity
  }
}

public struct EaselDesignProject: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public let name: String
  public let kind: EaselProjectKind
  public let designSystems: [EaselDesignSystemChoice]
  public let fidelity: EaselProjectFidelity
  public let workingDirectory: String
  public let createdAt: Date
  public let updatedAt: Date

  public var designSystem: EaselDesignSystemChoice {
    designSystems.first ?? .preset(.none)
  }

  public var designSystemDisplaySummary: String {
    designSystems.map(\.displayName).joined(separator: " -> ")
  }

  public init(
    id: UUID,
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemChoice,
    fidelity: EaselProjectFidelity,
    workingDirectory: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence([designSystem])
    self.fidelity = fidelity
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(
    id: UUID,
    name: String,
    kind: EaselProjectKind,
    designSystems: [EaselDesignSystemChoice],
    fidelity: EaselProjectFidelity,
    workingDirectory: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence(designSystems)
    self.fidelity = fidelity
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(
    id: UUID,
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemPreset,
    fidelity: EaselProjectFidelity,
    workingDirectory: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.designSystems = EaselDesignSystemChoice.normalizedPrecedence([.preset(designSystem)])
    self.fidelity = fidelity
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case kind
    case designSystem
    case designSystems
    case fidelity
    case workingDirectory
    case createdAt
    case updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    kind = try container.decode(EaselProjectKind.self, forKey: .kind)
    fidelity = try container.decode(EaselProjectFidelity.self, forKey: .fidelity)
    workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    if let decodedDesignSystems = try container.decodeIfPresent([EaselDesignSystemChoice].self, forKey: .designSystems) {
      designSystems = EaselDesignSystemChoice.normalizedPrecedence(decodedDesignSystems)
    } else {
      let legacyDesignSystem = try container.decode(EaselDesignSystemChoice.self, forKey: .designSystem)
      designSystems = EaselDesignSystemChoice.normalizedPrecedence([legacyDesignSystem])
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(kind, forKey: .kind)
    try container.encode(designSystem, forKey: .designSystem)
    try container.encode(designSystems, forKey: .designSystems)
    try container.encode(fidelity, forKey: .fidelity)
    try container.encode(workingDirectory, forKey: .workingDirectory)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

}

public struct EaselProjectLaunch: Sendable, Equatable {
  public let project: EaselDesignProject

  public init(project: EaselDesignProject) {
    self.project = project
  }
}
