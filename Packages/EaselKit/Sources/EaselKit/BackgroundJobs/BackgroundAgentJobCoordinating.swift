//
//  BackgroundAgentJobCoordinating.swift
//  EaselKit
//
//  UI-facing surface of the background job service. The concrete service is
//  @Observable, so views reading `jobs` through this existential re-render
//  on changes (same pattern as PreviewURLProviding).
//

import Foundation

// MARK: - BackgroundAgentJobCoordinating

@MainActor
public protocol BackgroundAgentJobCoordinating: AnyObject {
  /// All known jobs, newest last. UI filters by `request.projectPath`.
  var jobs: [BackgroundAgentJobSnapshot] { get }

  /// Enqueues a job (FIFO, one runs at a time) and returns its id.
  @discardableResult
  func submit(_ request: BackgroundAgentJobRequest) -> UUID

  /// Cancels a queued or running job. Best-effort for running agents.
  func cancel(jobId: UUID)

  /// Resolves a job in the `conflict` state.
  func resolveConflict(jobId: UUID, resolution: BackgroundAgentConflictResolution)

  /// Files edited again after the job applied (empty = safe to undo).
  /// UI confirms with the user before calling `undo(force: true)`.
  func postApplyDriftedFiles(jobId: UUID) async -> [String]

  /// Restores the pre-apply content of an applied job's files.
  func undo(jobId: UUID, force: Bool) async

  /// Resubmits a failed job's request as a new job.
  func retry(jobId: UUID)

  /// Removes a terminal job from `jobs` and cleans up its artifacts.
  func dismiss(jobId: UUID)
}
