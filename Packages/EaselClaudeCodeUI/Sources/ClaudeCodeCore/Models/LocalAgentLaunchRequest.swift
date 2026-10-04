//
//  LocalAgentLaunchRequest.swift
//  ClaudeCodeUI
//

import Foundation

public struct LocalAgentLaunchRequest: Equatable, Sendable {
  public let provider: LocalAgentProvider
  public let workingDirectory: String
  public let prompt: String
  public let command: String
  public let additionalPaths: [String]
  public let codexModel: String?
  /// OpenRouter model slug passed as `-m` for the arnes provider.
  public let arnesModel: String?
  public let extraArguments: [String]
  public let environment: [String: String]

  public init(
    provider: LocalAgentProvider,
    workingDirectory: String,
    prompt: String,
    command: String? = nil,
    additionalPaths: [String] = [],
    codexModel: String? = nil,
    arnesModel: String? = nil,
    extraArguments: [String] = [],
    environment: [String: String] = [:]
  ) {
    self.provider = provider
    self.workingDirectory = workingDirectory
    self.prompt = prompt
    self.command = command ?? provider.defaultCommand
    self.additionalPaths = additionalPaths
    self.codexModel = codexModel
    self.arnesModel = arnesModel
    self.extraArguments = extraArguments
    self.environment = environment
  }
}
