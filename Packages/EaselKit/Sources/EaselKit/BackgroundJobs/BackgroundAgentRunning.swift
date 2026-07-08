//
//  BackgroundAgentRunning.swift
//  EaselKit
//
//  Provider-agnostic headless agent runner. Implementations wrap one-shot
//  CLI runs (claude / codex exec) against a working directory; correctness
//  never depends on `onActivity`, which is cosmetic progress text only.
//

import Foundation

// MARK: - BackgroundAgentRunRequest

public struct BackgroundAgentRunRequest: Sendable {
  public let prompt: String
  /// Directory the agent runs in and is allowed to write to (the shadow root).
  public let workingDirectory: String
  /// Hard client-side kill switch for providers without real cancellation.
  public let timeout: TimeInterval

  public init(prompt: String, workingDirectory: String, timeout: TimeInterval) {
    self.prompt = prompt
    self.workingDirectory = workingDirectory
    self.timeout = timeout
  }
}

// MARK: - BackgroundAgentRunResult

public struct BackgroundAgentRunResult: Sendable {
  /// Raw final output of the run, kept for diagnostics.
  public let rawOutput: String

  public init(rawOutput: String) {
    self.rawOutput = rawOutput
  }
}

// MARK: - BackgroundAgentRunnerError

/// Provider-agnostic failures runners normalize SDK errors into, so the job
/// service can classify them without importing provider SDKs.
public enum BackgroundAgentRunnerError: Error, Equatable, Sendable {
  case timedOut
  case processFailed(String)
}

// MARK: - BackgroundAgentRunning

public protocol BackgroundAgentRunning: Sendable {
  /// Runs the agent to completion. `onActivity` receives cosmetic progress
  /// lines (e.g. "Editing index.html") on no particular actor.
  func run(
    _ request: BackgroundAgentRunRequest,
    onActivity: @escaping @Sendable (String) -> Void
  ) async throws -> BackgroundAgentRunResult

  /// Best-effort cancellation. Claude kills the process; Codex flags the
  /// run so its result is discarded (the process dies via timeout).
  func cancel() async
}
