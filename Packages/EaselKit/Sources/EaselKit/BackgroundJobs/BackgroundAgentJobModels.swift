//
//  BackgroundAgentJobModels.swift
//  EaselKit
//
//  Value vocabulary for background agent jobs: headless one-shot agent runs
//  that mutate project files outside the interactive chat session (currently
//  tweaks generation; designed so other flows can adopt the same pipeline).
//

import Foundation

// MARK: - BackgroundAgentJobKind

/// The feature a background job belongs to.
public enum BackgroundAgentJobKind: String, Sendable, Equatable {
  case tweaks
}

// MARK: - BackgroundAgentJobRequest

/// Everything needed to run one background job against a project.
public struct BackgroundAgentJobRequest: Sendable, Equatable {
  public let kind: BackgroundAgentJobKind
  /// Normalized absolute path of the project the job mutates.
  public let projectPath: String
  /// Project-relative path of the file the job primarily targets.
  public let targetFileRelativePath: String
  /// User-facing name of the target, for status UI.
  public let displayFileName: String
  /// Full prompt handed to the headless agent run.
  public let prompt: String
  /// Short user-facing description of the job ("Ideas", instruction excerpt).
  public let summary: String

  public init(
    kind: BackgroundAgentJobKind,
    projectPath: String,
    targetFileRelativePath: String,
    displayFileName: String,
    prompt: String,
    summary: String
  ) {
    self.kind = kind
    self.projectPath = projectPath
    self.targetFileRelativePath = targetFileRelativePath
    self.displayFileName = displayFileName
    self.prompt = prompt
    self.summary = summary
  }
}

// MARK: - BackgroundAgentJobStatus

/// Lifecycle of a background job.
public enum BackgroundAgentJobStatus: Sendable, Equatable {
  case queued
  /// Copying the project into the job's shadow workspace.
  case preparingWorkspace
  /// The headless agent process is running against the shadow workspace.
  case generating
  /// Diffing the shadow workspace and validating its output.
  case validating
  /// Validated and safe to apply, but a chat turn is in flight.
  case waitingToApply
  case applying
  case applied(undoAvailable: Bool)
  /// Files the job changed drifted in the real tree during generation.
  case conflict(driftedFiles: [String])
  case failed(BackgroundAgentJobFailure)
  case cancelled
  case undone

  /// True while the job still owns work (not a terminal state).
  public var isActive: Bool {
    switch self {
    case .queued, .preparingWorkspace, .generating, .validating, .waitingToApply, .applying:
      return true
    case .applied, .conflict, .failed, .cancelled, .undone:
      return false
    }
  }
}

// MARK: - BackgroundAgentJobFailure

/// Why a background job failed.
public enum BackgroundAgentJobFailure: Sendable, Equatable {
  case workspacePreparationFailed(String)
  case agentFailed(String)
  case timedOut
  case validationFailed(String)
  case applyFailed(String)

  /// User-facing failure description.
  public var message: String {
    switch self {
    case .workspacePreparationFailed(let detail):
      return "Couldn't prepare the workspace: \(detail)"
    case .agentFailed(let detail):
      return detail
    case .timedOut:
      return "Generation timed out"
    case .validationFailed(let detail):
      return detail
    case .applyFailed(let detail):
      return "Couldn't apply the changes: \(detail)"
    }
  }
}

// MARK: - BackgroundAgentConflictResolution

/// How the user chose to resolve a drift conflict.
public enum BackgroundAgentConflictResolution: Sendable {
  /// Re-run the same request against a fresh snapshot of the project.
  case regenerateOnLatest
  /// Apply the job's output, overwriting the drifted files (undo restores them).
  case applyAnyway
  /// Throw the job's output away.
  case discard
}

// MARK: - BackgroundAgentJobSnapshot

/// Immutable view of one job for UI consumption.
public struct BackgroundAgentJobSnapshot: Identifiable, Sendable, Equatable {
  public let id: UUID
  public let request: BackgroundAgentJobRequest
  public let status: BackgroundAgentJobStatus
  public let createdAt: Date
  /// When the agent run began; drives elapsed-time display.
  public let startedAt: Date?
  /// Project-relative paths the job changed (post-diff).
  public let changedFiles: [String]
  /// Cosmetic live-activity line, e.g. "Editing index.html".
  public let activityDescription: String?

  public init(
    id: UUID,
    request: BackgroundAgentJobRequest,
    status: BackgroundAgentJobStatus,
    createdAt: Date,
    startedAt: Date? = nil,
    changedFiles: [String] = [],
    activityDescription: String? = nil
  ) {
    self.id = id
    self.request = request
    self.status = status
    self.createdAt = createdAt
    self.startedAt = startedAt
    self.changedFiles = changedFiles
    self.activityDescription = activityDescription
  }
}
