//
//  LocalAgentLaunchError.swift
//  ClaudeCodeUI
//

import Foundation

public enum LocalAgentLaunchError: LocalizedError, Equatable {
  case missingWorkingDirectory
  case executableNotFound(String)
  case invalidShellValue(String)
  case scriptWriteFailed(String)
  case terminalOpenFailed

  public var errorDescription: String? {
    switch self {
    case .missingWorkingDirectory:
      return "Select an Easel project before starting an agent."
    case .executableNotFound(let command):
      return "Could not find '\(command)' command."
    case .invalidShellValue(let valueName):
      return "\(valueName) contains characters that cannot be used in a terminal launch."
    case .scriptWriteFailed(let message):
      return "Failed to create terminal launch script: \(message)"
    case .terminalOpenFailed:
      return "Terminal could not open the launch script."
    }
  }
}
