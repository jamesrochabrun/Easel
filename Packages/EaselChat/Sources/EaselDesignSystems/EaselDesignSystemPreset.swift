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

}
