//
//  DesignLibrarySelection.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation

public enum DesignLibrarySelection: Sendable {
  case project(EaselDesignProject, latestSession: StoredSession?)
  case designSystem(EaselDesignSystemProfile, latestSession: StoredSession?)

  public var workingDirectory: String {
    switch self {
    case .project(let project, _):
      return project.workingDirectory
    case .designSystem(let profile, _):
      return profile.workingDirectory
    }
  }

  public var latestSession: StoredSession? {
    switch self {
    case .project(_, let latestSession), .designSystem(_, let latestSession):
      return latestSession
    }
  }

  public var latestSessionID: String? {
    latestSession?.id
  }
}
