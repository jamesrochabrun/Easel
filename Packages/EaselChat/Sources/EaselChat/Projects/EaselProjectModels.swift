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
  public let designSystem: EaselDesignSystemChoice
  public let fidelity: EaselProjectFidelity

  public init(
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemChoice,
    fidelity: EaselProjectFidelity
  ) {
    self.name = name
    self.kind = kind
    self.designSystem = designSystem
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
    self.designSystem = .preset(designSystem)
    self.fidelity = fidelity
  }
}

public struct EaselDesignProject: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public let name: String
  public let kind: EaselProjectKind
  public let designSystem: EaselDesignSystemChoice
  public let fidelity: EaselProjectFidelity
  public let workingDirectory: String
  public let createdAt: Date
  public let updatedAt: Date

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
    self.designSystem = designSystem
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
    self.designSystem = .preset(designSystem)
    self.fidelity = fidelity
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

}

public struct EaselProjectLaunch: Sendable, Equatable {
  public let project: EaselDesignProject

  public init(project: EaselDesignProject) {
    self.project = project
  }
}
