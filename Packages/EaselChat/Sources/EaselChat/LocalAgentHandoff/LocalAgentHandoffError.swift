//
//  LocalAgentHandoffError.swift
//  EaselChat
//

import Foundation

public enum LocalAgentHandoffError: LocalizedError, Equatable, Sendable {
  case missingCodebase
  case missingSelectedRepository
  case missingProjectFolder
  case projectDirectoryCreationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .missingCodebase:
      return "Attach a codebase to this high-fidelity prototype first."
    case .missingSelectedRepository:
      return "Select a repo before starting the handoff."
    case .missingProjectFolder:
      return "Select a root folder for your project before starting the handoff."
    case let .projectDirectoryCreationFailed(message):
      return "Could not create the project folder. \(message)"
    }
  }
}
