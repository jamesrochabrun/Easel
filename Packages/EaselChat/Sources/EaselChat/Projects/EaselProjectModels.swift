//
//  EaselProjectModels.swift
//  EaselChat
//

import Foundation

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

  var promptDescription: String {
    switch self {
    case .wireframe:
      return "a clear wireframe with strong structure, hierarchy, and interaction states"
    case .highFidelity:
      return "a polished high-fidelity design with refined visual details, realistic content, and production-quality interaction states"
    }
  }
}

public enum EaselDesignSystemPreset: String, CaseIterable, Codable, Identifiable, Sendable {
  case airbnb
  case apple
  case material
  case none

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .airbnb:
      return "Airbnb Design System"
    case .apple:
      return "Apple HIG"
    case .material:
      return "Material Design"
    case .none:
      return "No preset"
    }
  }

  var detail: String {
    switch self {
    case .airbnb:
      return "Org default"
    case .apple:
      return "Apple platforms"
    case .material:
      return "Web and Android"
    case .none:
      return "Start clean"
    }
  }

  var promptInstruction: String {
    switch self {
    case .airbnb:
      return "Use an Airbnb-inspired product design language: warm neutrals, clear spacing, approachable controls, and polished marketplace-quality UI."
    case .apple:
      return "Use Apple Human Interface Guidelines: restrained surfaces, clear hierarchy, native-feeling controls, and excellent accessibility."
    case .material:
      return "Use Material Design principles: explicit elevation, clear component states, strong rhythm, and accessible color contrast."
    case .none:
      return "Create an original design system appropriate for the product, with a cohesive type, spacing, color, and component language."
    }
  }
}

public struct EaselProjectCreateRequest: Sendable, Equatable {
  public let name: String
  public let kind: EaselProjectKind
  public let designSystem: EaselDesignSystemPreset
  public let fidelity: EaselProjectFidelity

  public init(
    name: String,
    kind: EaselProjectKind,
    designSystem: EaselDesignSystemPreset,
    fidelity: EaselProjectFidelity
  ) {
    self.name = name
    self.kind = kind
    self.designSystem = designSystem
    self.fidelity = fidelity
  }
}

public struct EaselDesignProject: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public let name: String
  public let kind: EaselProjectKind
  public let designSystem: EaselDesignSystemPreset
  public let fidelity: EaselProjectFidelity
  public let workingDirectory: String
  public let createdAt: Date
  public let updatedAt: Date

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
    self.designSystem = designSystem
    self.fidelity = fidelity
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public func launchPrompt(seedPrompt: String? = nil) -> String {
    var lines: [String] = [
      "You are building a Codex Design \(kind.displayName.lowercased()) project in this folder.",
      "Project name: \(name)",
      "Working directory: \(workingDirectory)",
      "Target fidelity: \(fidelity.displayName)",
      designSystem.promptInstruction,
      "Keep `npm run dev` working so Easel can preview the project.",
    ]

    switch kind {
    case .prototype:
      lines.append("Create \(fidelity.promptDescription) for the requested product experience.")
    case .slideDeck:
      lines.append("Create a slide deck experience with a strong narrative arc, polished slide layouts, speaker-friendly pacing, and responsive presentation controls.")
    }

    if let seedPrompt, !seedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines.append("User brief: \(seedPrompt.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    lines.append("Start by inspecting the existing scaffold, then replace or extend it as needed.")
    return lines.joined(separator: "\n")
  }
}

public struct EaselProjectLaunch: Sendable, Equatable {
  public let project: EaselDesignProject
  public let prompt: String

  public init(project: EaselDesignProject, prompt: String) {
    self.project = project
    self.prompt = prompt
  }
}
