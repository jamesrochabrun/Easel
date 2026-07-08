//
//  CodexBackgroundAgentRunner.swift
//  ClaudeCodeUI
//
//  Headless one-shot `codex exec` run for background jobs. CodexSDK exposes
//  no process handle, so cancel() only flags the run — the caller discards
//  the result and the process dies via the request timeout at the latest.
//  Safe because background jobs only ever write to a throwaway shadow
//  workspace.
//

import CodexSDK
import EaselKit
import Foundation

// MARK: - CodexBackgroundAgentRunner

public actor CodexBackgroundAgentRunner: BackgroundAgentRunning {
  private let commandOverride: String?
  private let environmentOverrides: [String: String]
  private let model: String?
  private let extraArguments: [String]
  private var isCancelled = false

  public init(
    commandOverride: String?,
    environmentOverrides: [String: String],
    model: String?,
    extraArguments: [String]
  ) {
    self.commandOverride = commandOverride
    self.environmentOverrides = environmentOverrides
    self.model = model
    self.extraArguments = extraArguments
  }

  public func run(
    _ request: BackgroundAgentRunRequest,
    onActivity: @escaping @Sendable (String) -> Void
  ) async throws -> BackgroundAgentRunResult {
    let client = CodexClientFactory.makeClient(
      commandOverride: commandOverride,
      environmentOverrides: environmentOverrides,
      workingDirectory: request.workingDirectory
    )
    let options = Self.makeOptions(
      workingDirectory: request.workingDirectory,
      model: model,
      extraArguments: extraArguments,
      timeout: request.timeout
    )

    let result: CodexExecResult
    do {
      result = try await client.run(prompt: request.prompt, options: options) { event in
        if let activity = Self.activityDescription(for: event) {
          onActivity(activity)
        }
      }
    } catch {
      if isCancelled { throw CancellationError() }
      throw Self.normalized(error)
    }

    if isCancelled { throw CancellationError() }
    guard result.exitCode == 0 else {
      throw BackgroundAgentRunnerError.processFailed(
        "codex exited with code \(result.exitCode): \(String(result.stderr.suffix(300)))"
      )
    }
    return BackgroundAgentRunResult(rawOutput: result.stdout)
  }

  public func cancel() {
    isCancelled = true
  }

  /// First-turn `codex exec` options identical to the interactive chat's,
  /// pointed at the shadow workspace with the job's kill-switch timeout.
  nonisolated static func makeOptions(
    workingDirectory: String,
    model: String?,
    extraArguments: [String],
    timeout: TimeInterval
  ) -> CodexExecOptions {
    var options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: workingDirectory,
      modelIdentifier: model,
      extraArguments: extraArguments
    )
    options.timeout = timeout
    return options
  }

  nonisolated static func activityDescription(for event: CodexExecEvent) -> String? {
    guard case .jsonEvent(let json) = event,
          let item = json.item,
          item.type == "file_change" else {
      return nil
    }
    var paths = item.changes?.compactMap(\.path) ?? []
    if paths.isEmpty, let legacyPath = item.filePath {
      paths = [legacyPath]
    }
    guard let path = paths.last else { return nil }
    return "Editing \((path as NSString).lastPathComponent)"
  }

  nonisolated static func normalized(_ error: Error) -> Error {
    guard let execError = error as? CodexExecError else { return error }
    switch execError {
    case .timeout:
      return BackgroundAgentRunnerError.timedOut
    case .nonZeroExit(let exitCode, let stderr):
      return BackgroundAgentRunnerError.processFailed(
        "codex exited with code \(exitCode): \(String(stderr.suffix(300)))"
      )
    case .promptRequired, .commandNotFound, .processLaunchFailed, .invalidConfiguration:
      return BackgroundAgentRunnerError.processFailed(execError.description)
    }
  }
}
