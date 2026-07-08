//
//  ClaudeBackgroundAgentRunner.swift
//  ClaudeCodeUI
//
//  Headless one-shot Claude run for background jobs. Uses a dedicated
//  client per run with the working directory pointed at the job's shadow
//  workspace; cancel() kills the underlying process for real.
//

import ClaudeCodeSDK
import EaselKit
import Foundation

// MARK: - ClaudeBackgroundAgentRunner

public actor ClaudeBackgroundAgentRunner: BackgroundAgentRunning {
  private let baseConfiguration: ClaudeCodeConfiguration
  private let model: String?
  private let appendSystemPrompt: String?
  private var activeClient: ClaudeCodeClient?
  private var isCancelled = false

  public init(
    baseConfiguration: ClaudeCodeConfiguration,
    model: String?,
    appendSystemPrompt: String?
  ) {
    self.baseConfiguration = baseConfiguration
    self.model = model
    self.appendSystemPrompt = appendSystemPrompt
  }

  public func run(
    _ request: BackgroundAgentRunRequest,
    onActivity: @escaping @Sendable (String) -> Void
  ) async throws -> BackgroundAgentRunResult {
    var configuration = baseConfiguration
    configuration.workingDirectory = request.workingDirectory
    let client = try ClaudeCodeClient(configuration: configuration)

    if isCancelled { throw CancellationError() }
    activeClient = client
    defer { activeClient = nil }

    let options = Self.makeOptions(
      model: model,
      timeout: request.timeout,
      appendSystemPrompt: appendSystemPrompt
    )

    let result: ClaudeCodeResult
    do {
      result = try await client.runSinglePrompt(
        prompt: request.prompt,
        outputFormat: .text,
        options: options
      )
    } catch {
      if isCancelled { throw CancellationError() }
      throw Self.normalized(error)
    }

    if isCancelled { throw CancellationError() }
    switch result {
    case .text(let output):
      return BackgroundAgentRunResult(rawOutput: output)
    case .json, .stream:
      // Not produced for .text output format; nothing useful to keep.
      return BackgroundAgentRunResult(rawOutput: "")
    }
  }

  public func cancel() {
    isCancelled = true
    activeClient?.cancel()
  }

  nonisolated static func makeOptions(
    model: String?,
    timeout: TimeInterval,
    appendSystemPrompt: String?
  ) -> ClaudeCodeOptions {
    var options = ClaudeCodeOptions()
    // Mirrors the interactive path (ClaudeChatRuntimeOptionsBuilder): Easel
    // relies on bypassPermissions, not the MCP approval server.
    options.permissionMode = .bypassPermissions
    options.maxTurns = 30
    options.timeout = timeout
    if let model, !model.isEmpty {
      options.model = model
    }
    if let appendSystemPrompt, !appendSystemPrompt.isEmpty {
      options.appendSystemPrompt = appendSystemPrompt
    }
    return options
  }

  nonisolated static func normalized(_ error: Error) -> Error {
    guard let claudeError = error as? ClaudeCodeError else { return error }
    if case .timeout = claudeError {
      return BackgroundAgentRunnerError.timedOut
    }
    return error
  }
}
