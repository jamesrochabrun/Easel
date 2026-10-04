//
//  LocalAgentHandoffContext.swift
//  EaselChat
//

import Foundation

public struct LocalAgentHandoffContext: Equatable, Sendable {
  public let easelProjectPath: String
  public let codebasePath: String?
  public let project: EaselDesignProject?
  public let previewURL: URL?
  public let claudeCommand: String
  public let claudeAdditionalPaths: [String]
  public let codexCommand: String
  public let codexModel: String
  public let codexExtraArgs: String
  public let codexEnvironmentVariables: [String: String]
  public let arnesCommand: String
  public let arnesModel: String
  public let arnesExtraArgs: String
  public let arnesEnvironmentVariables: [String: String]

  public init(
    easelProjectPath: String,
    codebasePath: String?,
    project: EaselDesignProject?,
    previewURL: URL?,
    claudeCommand: String,
    claudeAdditionalPaths: [String],
    codexCommand: String,
    codexModel: String,
    codexExtraArgs: String,
    codexEnvironmentVariables: [String: String],
    arnesCommand: String = "",
    arnesModel: String = "",
    arnesExtraArgs: String = "",
    arnesEnvironmentVariables: [String: String] = [:]
  ) {
    self.easelProjectPath = easelProjectPath
    self.codebasePath = codebasePath
    self.project = project
    self.previewURL = previewURL
    self.claudeCommand = claudeCommand
    self.claudeAdditionalPaths = claudeAdditionalPaths
    self.codexCommand = codexCommand
    self.codexModel = codexModel
    self.codexExtraArgs = codexExtraArgs
    self.codexEnvironmentVariables = codexEnvironmentVariables
    self.arnesCommand = arnesCommand
    self.arnesModel = arnesModel
    self.arnesExtraArgs = arnesExtraArgs
    self.arnesEnvironmentVariables = arnesEnvironmentVariables
  }
}
