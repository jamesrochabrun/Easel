//
//  EaselDesignSystemPreset.swift
//  EaselDesignSystems
//

import Foundation

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
      return "No design system"
    }
  }

  public var detail: String {
    switch self {
    case .airbnb:
      return "Org default"
    case .apple:
      return "Apple platforms"
    case .material:
      return "Web and Android"
    case .none:
      return "Start without a design system"
    }
  }

  public var promptInstruction: String {
    switch self {
    case .airbnb:
      return "Use an Airbnb-inspired product design language: warm neutrals, clear spacing, approachable controls, and polished marketplace-quality UI."
    case .apple:
      return "Use Apple Human Interface Guidelines: restrained surfaces, clear hierarchy, native-feeling controls, and excellent accessibility."
    case .material:
      return "Use Material Design principles: explicit elevation, clear component states, strong rhythm, and accessible color contrast."
    case .none:
      return "No design system was selected. Create an original product UI appropriate for the request, with cohesive type, spacing, color, and component language."
    }
  }
}
