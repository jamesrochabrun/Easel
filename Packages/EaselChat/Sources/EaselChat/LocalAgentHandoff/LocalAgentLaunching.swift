//
//  LocalAgentLaunching.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

public protocol LocalAgentLaunching: Sendable {
  func launch(_ request: LocalAgentLaunchRequest) async throws
}

public struct TerminalLocalAgentLauncher: LocalAgentLaunching {
  public init() {}

  public func launch(_ request: LocalAgentLaunchRequest) async throws {
    try await TerminalLauncher.launchLocalAgent(request)
  }
}
