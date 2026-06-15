//
//  LocalAgentHandoffViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

@Observable @MainActor
public final class LocalAgentHandoffViewModel {
  public var selectedProvider: LocalAgentProvider = .codex
  public var selectedTarget: LocalAgentHandoffTarget = .newProject
  public var details = ""
  public private(set) var selectedRepositoryPath: String?
  public private(set) var createdProjectPath: String?
  public private(set) var isCreatingProject = false
  public private(set) var isLaunching = false
  public private(set) var errorMessage: String?
  public private(set) var successMessage: String?

  private let launcher: any LocalAgentLaunching
  private let workspaceCreator: any LocalAgentHandoffWorkspaceCreating
  private var presentationProjectPath: String?

  public init(
    launcher: any LocalAgentLaunching = TerminalLocalAgentLauncher(),
    workspaceCreator: any LocalAgentHandoffWorkspaceCreating = DefaultLocalAgentHandoffWorkspaceCreator()
  ) {
    self.launcher = launcher
    self.workspaceCreator = workspaceCreator
  }

  public func prepareForPresentation(context: LocalAgentHandoffContext?) {
    resetStatus()

    let contextProjectPath = context?.easelProjectPath
    if presentationProjectPath != contextProjectPath {
      createdProjectPath = nil
      presentationProjectPath = contextProjectPath
    }

    if context?.codebasePath != nil {
      selectedTarget = .codebase
    } else if selectedTarget == .codebase {
      selectedTarget = selectedRepositoryPath == nil ? .newProject : .selectedRepository
    }
  }

  public func resetStatus() {
    errorMessage = nil
    successMessage = nil
  }

  public func selectRepository(_ url: URL) {
    selectedRepositoryPath = url.standardizedFileURL.resolvingSymlinksInPath().path
    selectedTarget = .selectedRepository
    resetStatus()
  }

  public func clearSelectedRepository() {
    selectedRepositoryPath = nil
    if selectedTarget == .selectedRepository {
      selectedTarget = .newProject
    }
  }

  public func reportRepositorySelectionFailure(_ error: Error) {
    errorMessage = error.localizedDescription
  }

  public func canLaunch(context: LocalAgentHandoffContext?) -> Bool {
    guard context != nil, !isLaunching, !isCreatingProject else {
      return false
    }

    switch selectedTarget {
    case .codebase:
      return context?.codebasePath != nil
    case .selectedRepository:
      return selectedRepositoryPath != nil
    case .newProject:
      return createdProjectPath != nil
    }
  }

  public func canCreateProject(context: LocalAgentHandoffContext?) -> Bool {
    context != nil && !isCreatingProject && createdProjectPath == nil
  }

  public func createProject(context: LocalAgentHandoffContext, in parentDirectory: URL) async {
    guard !isCreatingProject, createdProjectPath == nil else { return }

    isCreatingProject = true
    resetStatus()
    defer { isCreatingProject = false }

    do {
      createdProjectPath = try await workspaceCreator.createWorkspace(for: context, in: parentDirectory)
      successMessage = "Created project folder."
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func launch(context: LocalAgentHandoffContext) async {
    guard !isLaunching else { return }

    isLaunching = true
    resetStatus()
    defer { isLaunching = false }

    do {
      try await launcher.launch(try await launchRequest(context: context))
      successMessage = "Started \(selectedProvider.displayName) in Terminal."
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func launchRequest(context: LocalAgentHandoffContext) async throws -> LocalAgentLaunchRequest {
    let workingDirectory = try await resolvedWorkingDirectory(for: context)
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: details,
      context: context
    )

    switch selectedProvider {
    case .codex:
      return LocalAgentLaunchRequest(
        provider: .codex,
        workingDirectory: workingDirectory,
        prompt: prompt,
        command: normalizedCommand(context.codexCommand),
        additionalPaths: [],
        codexModel: normalizedCommand(context.codexModel),
        extraArguments: LocalAgentArgumentParser.parse(context.codexExtraArgs),
        environment: context.codexEnvironmentVariables
      )

    case .claude:
      return LocalAgentLaunchRequest(
        provider: .claude,
        workingDirectory: workingDirectory,
        prompt: prompt,
        command: normalizedCommand(context.claudeCommand),
        additionalPaths: context.claudeAdditionalPaths
      )
    }
  }

  private func normalizedCommand(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func resolvedWorkingDirectory(for context: LocalAgentHandoffContext) async throws -> String {
    switch selectedTarget {
    case .codebase:
      guard let codebasePath = context.codebasePath else {
        throw LocalAgentHandoffError.missingCodebase
      }

      return codebasePath

    case .selectedRepository:
      guard let selectedRepositoryPath else {
        throw LocalAgentHandoffError.missingSelectedRepository
      }

      return selectedRepositoryPath

    case .newProject:
      if let createdProjectPath {
        return createdProjectPath
      }

      throw LocalAgentHandoffError.missingProjectFolder
    }
  }
}
