//
//  LocalAgentHandoffTarget.swift
//  EaselChat
//

import Foundation

public enum LocalAgentHandoffTarget: String, CaseIterable, Identifiable, Sendable {
  case codebase
  case selectedRepository
  case newProject

  public var id: String { rawValue }

  var displayName: String {
    switch self {
    case .codebase:
      return "Implement in Codebase"
    case .selectedRepository:
      return "Select Repo"
    case .newProject:
      return "Create Project"
    }
  }

  static func availableTargets(hasCodebase: Bool) -> [Self] {
    if hasCodebase {
      return allCases
    }

    return [.selectedRepository, .newProject]
  }
}
