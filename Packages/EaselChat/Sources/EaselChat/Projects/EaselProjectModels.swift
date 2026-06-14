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
      return """
      Help the user explore design ideas quickly. Interview them, then generate multiple rough wireframes to map out the design space before committing to a direction. Prioritize breadth over polish: show 3-5 distinctly different approaches for each idea. Use simple shapes, placeholder text, and minimal color to keep the focus on structure and flow. Use a sketchy vibe -- handwritten but readable fonts; b&w with some color; low-fi and simple. Provide simple tweaks; show options side-by-side if small or using a tab control if large.
      """
    case .highFidelity:
      return """
      Create a high-fidelity, polished design that's also a fully interactive prototype — it should feel like a real working app, not a static mockup.
      Behavior: Use React useState/useEffect for dynamic behavior. Include hover states, click interactions, form validation, animated transitions, and multi-step navigation flows with realistic state management.
      Design process (use the todo list to remember): (1) ask questions, (2) find existing UI kits and collect design context — copy ALL relevant components and read ALL relevant examples; ask the user if you can't find them, (3) start your file with assumptions + context + design reasoning (as if you are a junior designer and the user is your manager), with placeholders for the designs, and show it to the user early, (4) build out the designs and show the user again ASAP; append some next steps, (5) use your tools to check, verify and iterate on the design.
      Good hi-fi designs do not start from scratch — they are rooted in existing design context. Ask the user to import their codebase, or find a suitable UI kit / design resources.
      """
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
