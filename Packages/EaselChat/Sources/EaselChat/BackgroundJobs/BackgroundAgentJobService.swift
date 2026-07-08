//
//  BackgroundAgentJobService.swift
//  EaselChat
//
//  Orchestrates background agent jobs: FIFO queue, shadow-workspace runs,
//  validation, drift-aware auto-apply (deferring while a chat turn is in
//  flight), conflict resolution, cancel, and undo. Runs entirely on the
//  main actor; file work happens inside the injected actors.
//

import EaselKit
import Foundation
import OSLog

private let jobLog = Logger(subsystem: "com.easel.chat", category: "BackgroundAgentJobService")

// MARK: - BackgroundAgentJobService

@Observable @MainActor
public final class BackgroundAgentJobService: BackgroundAgentJobCoordinating {

  // MARK: - Observable state

  public private(set) var jobs: [BackgroundAgentJobSnapshot] = []

  // MARK: - Dependencies

  @ObservationIgnored private let runnerProvider: @MainActor () throws -> any BackgroundAgentRunning
  @ObservationIgnored private let validator: any BackgroundJobValidating
  @ObservationIgnored private let isChatBusy: @MainActor (_ projectPath: String) -> Bool
  @ObservationIgnored private let workspaceManager: any ShadowWorkspacing
  @ObservationIgnored private let applyEngine: any BackgroundJobApplying
  @ObservationIgnored private let generationTimeout: TimeInterval
  @ObservationIgnored private let idlePollInterval: Duration

  // MARK: - Internal job state

  private final class JobRecord {
    let id: UUID
    let request: BackgroundAgentJobRequest
    var status: BackgroundAgentJobStatus
    let createdAt: Date
    var startedAt: Date?
    var activity: String?
    var changedFiles: [ShadowFileChange] = []
    var workspace: ShadowWorkspace?
    var appliedRecord: AppliedJobRecord?
    var activeRunner: (any BackgroundAgentRunning)?
    var pipelineTask: Task<Void, Never>?

    init(request: BackgroundAgentJobRequest) {
      self.id = UUID()
      self.request = request
      self.status = .queued
      self.createdAt = Date()
    }
  }

  @ObservationIgnored private var records: [UUID: JobRecord] = [:]
  @ObservationIgnored private var order: [UUID] = []
  @ObservationIgnored private var queue: [UUID] = []
  @ObservationIgnored private var runningJobId: UUID?
  @ObservationIgnored private var sweptProjects: Set<String> = []

  // MARK: - Init

  public init(
    runnerProvider: @escaping @MainActor () throws -> any BackgroundAgentRunning,
    validator: any BackgroundJobValidating,
    isChatBusy: @escaping @MainActor (_ projectPath: String) -> Bool,
    workspaceManager: any ShadowWorkspacing = ShadowWorkspaceManager(),
    applyEngine: any BackgroundJobApplying = BackgroundJobApplyEngine(),
    generationTimeout: TimeInterval = 600,
    idlePollInterval: Duration = .milliseconds(500)
  ) {
    self.runnerProvider = runnerProvider
    self.validator = validator
    self.isChatBusy = isChatBusy
    self.workspaceManager = workspaceManager
    self.applyEngine = applyEngine
    self.generationTimeout = generationTimeout
    self.idlePollInterval = idlePollInterval
  }

  // MARK: - BackgroundAgentJobCoordinating

  @discardableResult
  public func submit(_ request: BackgroundAgentJobRequest) -> UUID {
    dismissTerminalJobs(projectPath: request.projectPath)

    let record = JobRecord(request: request)
    records[record.id] = record
    order.append(record.id)
    queue.append(record.id)
    publishJobs()
    maybeStartNext()
    return record.id
  }

  public func cancel(jobId: UUID) {
    guard let record = records[jobId] else { return }
    switch record.status {
    case .queued:
      queue.removeAll { $0 == jobId }
      setStatus(record, .cancelled)
      Task { [workspaceManager] in
        await workspaceManager.cleanup(projectPath: record.request.projectPath, jobId: jobId)
      }

    case .preparingWorkspace, .generating, .validating, .waitingToApply:
      // Flip status now so the UI reacts instantly; the pipeline task notices
      // after its current await, cleans up the shadow, and exits. The queue
      // advances immediately — an abandoned codex process only ever writes
      // to this job's own shadow, so the next job is safe to start.
      setStatus(record, .cancelled)
      if let runner = record.activeRunner {
        Task { await runner.cancel() }
      }
      advanceQueue(after: jobId)

    case .applying, .applied, .conflict, .failed, .cancelled, .undone:
      break
    }
  }

  public func resolveConflict(jobId: UUID, resolution: BackgroundAgentConflictResolution) {
    guard let record = records[jobId], case .conflict = record.status else { return }

    switch resolution {
    case .regenerateOnLatest:
      let request = record.request
      dismiss(jobId: jobId)
      submit(request)

    case .applyAnyway:
      guard let workspace = record.workspace else {
        fail(record, .applyFailed("The job's workspace is no longer available"))
        return
      }
      record.pipelineTask = Task { [weak self] in
        await self?.performApply(jobId: jobId, workspace: workspace, skipDriftCheck: true)
      }

    case .discard:
      setStatus(record, .cancelled)
      Task { [workspaceManager] in
        await workspaceManager.cleanup(projectPath: record.request.projectPath, jobId: jobId)
      }
    }
  }

  public func postApplyDriftedFiles(jobId: UUID) async -> [String] {
    guard let record = records[jobId], let applied = record.appliedRecord else { return [] }
    return await applyEngine.postApplyDrift(record: applied)
  }

  public func undo(jobId: UUID, force: Bool) async {
    guard let record = records[jobId],
          case .applied = record.status,
          let applied = record.appliedRecord else {
      return
    }

    if !force {
      let drift = await applyEngine.postApplyDrift(record: applied)
      guard drift.isEmpty else {
        jobLog.info("Undo blocked by post-apply drift: \(drift.joined(separator: ", "))")
        return
      }
    }

    do {
      try await applyEngine.undo(record: applied)
      setStatus(record, .undone)
      await workspaceManager.cleanup(projectPath: record.request.projectPath, jobId: jobId)
    } catch {
      fail(record, .applyFailed("Undo failed: \(error.localizedDescription)"))
    }
  }

  public func retry(jobId: UUID) {
    guard let record = records[jobId], case .failed = record.status else { return }
    let request = record.request
    dismiss(jobId: jobId)
    submit(request)
  }

  public func dismiss(jobId: UUID) {
    guard let record = records[jobId], !record.status.isActive else { return }
    records[jobId] = nil
    order.removeAll { $0 == jobId }
    queue.removeAll { $0 == jobId }
    publishJobs()
    Task { [workspaceManager] in
      await workspaceManager.cleanup(projectPath: record.request.projectPath, jobId: jobId)
    }
  }

  // MARK: - Queue

  private func maybeStartNext() {
    guard runningJobId == nil else { return }
    while !queue.isEmpty {
      let jobId = queue.removeFirst()
      guard let record = records[jobId], record.status == .queued else { continue }
      runningJobId = jobId
      record.pipelineTask = Task { [weak self] in
        await self?.runPipeline(jobId: jobId)
      }
      return
    }
  }

  private func advanceQueue(after jobId: UUID) {
    guard runningJobId == jobId else { return }
    runningJobId = nil
    maybeStartNext()
  }

  // MARK: - Pipeline

  private func runPipeline(jobId: UUID) async {
    guard let record = records[jobId] else {
      advanceQueue(after: jobId)
      return
    }
    let projectPath = record.request.projectPath

    // One sweep of orphaned artifacts (crash/quit leftovers) per project.
    if !sweptProjects.contains(projectPath) {
      sweptProjects.insert(projectPath)
      let liveIds = Set(records.values.filter { $0.request.projectPath == projectPath }.map(\.id))
      await workspaceManager.sweepStaleArtifacts(projectPath: projectPath, keeping: liveIds)
      if await bailIfCancelled(record) { return }
    }

    // 1. Shadow workspace.
    setStatus(record, .preparingWorkspace)
    let workspace: ShadowWorkspace
    do {
      workspace = try await workspaceManager.create(projectPath: projectPath, jobId: record.id)
    } catch {
      if await bailIfCancelled(record) { return }
      fail(record, .workspacePreparationFailed(error.localizedDescription))
      return
    }
    record.workspace = workspace
    if await bailIfCancelled(record) { return }

    // 2. Headless agent run.
    let runner: any BackgroundAgentRunning
    do {
      runner = try runnerProvider()
    } catch {
      fail(record, .agentFailed(error.localizedDescription))
      return
    }
    record.activeRunner = runner
    record.startedAt = Date()
    setStatus(record, .generating)

    let runRequest = BackgroundAgentRunRequest(
      prompt: record.request.prompt,
      workingDirectory: workspace.rootPath,
      timeout: generationTimeout
    )
    do {
      _ = try await runner.run(runRequest) { [weak self, jobId] activity in
        Task { @MainActor [weak self] in
          self?.updateActivity(jobId: jobId, activity: activity)
        }
      }
    } catch {
      record.activeRunner = nil
      if await bailIfCancelled(record) { return }
      if (error as? BackgroundAgentRunnerError) == .timedOut {
        fail(record, .timedOut)
      } else if error is CancellationError {
        // Runner was cancelled without the job being cancelled first —
        // defensive; treat it like a user cancellation.
        setStatus(record, .cancelled)
        await cleanupArtifacts(record)
        advanceQueue(after: record.id)
      } else {
        fail(record, .agentFailed(error.localizedDescription))
      }
      return
    }
    record.activeRunner = nil
    if await bailIfCancelled(record) { return }

    // 3. Diff + validate.
    setStatus(record, .validating)
    let changes: [ShadowFileChange]
    do {
      changes = try await workspaceManager.changedFiles(in: workspace)
    } catch {
      if await bailIfCancelled(record) { return }
      fail(record, .validationFailed("Couldn't inspect the generated changes: \(error.localizedDescription)"))
      return
    }
    if await bailIfCancelled(record) { return }

    let applicable = changes.filter { $0.kind != .deleted }
    let skippedDeletions = changes.count - applicable.count
    if skippedDeletions > 0 {
      jobLog.info("Job \(record.id) skipped \(skippedDeletions) deletion(s); deletions are not applied")
    }
    guard !applicable.isEmpty else {
      fail(record, .validationFailed("The agent didn't change any files"))
      return
    }
    record.changedFiles = applicable

    do {
      _ = try await validator.validate(
        shadowRoot: workspace.rootPath,
        targetRelativePath: record.request.targetFileRelativePath,
        changedFiles: applicable.map(\.relativePath)
      )
    } catch {
      if await bailIfCancelled(record) { return }
      fail(record, .validationFailed(error.localizedDescription))
      return
    }
    if await bailIfCancelled(record) { return }

    // 4. Apply when safe.
    await applyWhenSafe(record, workspace: workspace)
  }

  private func applyWhenSafe(_ record: JobRecord, workspace: ShadowWorkspace) async {
    let projectPath = record.request.projectPath

    // Surface drift immediately (knob writes or chat edits during generation).
    let drifted = await applyEngine.driftedFiles(
      changes: record.changedFiles,
      manifest: workspace.manifest,
      projectPath: projectPath
    )
    if await bailIfCancelled(record) { return }
    guard drifted.isEmpty else {
      setStatus(record, .conflict(driftedFiles: drifted))
      advanceQueue(after: record.id)
      return
    }

    if isChatBusy(projectPath) {
      setStatus(record, .waitingToApply)
      while isChatBusy(projectPath) {
        try? await Task.sleep(for: idlePollInterval)
        if await bailIfCancelled(record) { return }
      }
    }

    await performApply(jobId: record.id, workspace: workspace, skipDriftCheck: false)
  }

  private func performApply(jobId: UUID, workspace: ShadowWorkspace, skipDriftCheck: Bool) async {
    guard let record = records[jobId] else {
      advanceQueue(after: jobId)
      return
    }

    if !skipDriftCheck {
      // Final re-check immediately before writes shrinks the race window.
      let drifted = await applyEngine.driftedFiles(
        changes: record.changedFiles,
        manifest: workspace.manifest,
        projectPath: record.request.projectPath
      )
      if await bailIfCancelled(record) { return }
      guard drifted.isEmpty else {
        setStatus(record, .conflict(driftedFiles: drifted))
        advanceQueue(after: record.id)
        return
      }
    }

    setStatus(record, .applying)
    do {
      let applied = try await applyEngine.apply(changes: record.changedFiles, workspace: workspace)
      record.appliedRecord = applied
      setStatus(record, .applied(undoAvailable: true))
    } catch {
      fail(record, .applyFailed(error.localizedDescription))
    }
    advanceQueue(after: record.id)
  }

  // MARK: - State helpers

  /// True (and performs shadow cleanup + queue advance) when the job was
  /// cancelled while the pipeline was suspended.
  private func bailIfCancelled(_ record: JobRecord) async -> Bool {
    guard case .cancelled = record.status else { return false }
    await cleanupArtifacts(record)
    advanceQueue(after: record.id)
    return true
  }

  private func cleanupArtifacts(_ record: JobRecord) async {
    await workspaceManager.cleanup(projectPath: record.request.projectPath, jobId: record.id)
  }

  private func fail(_ record: JobRecord, _ failure: BackgroundAgentJobFailure) {
    jobLog.error("Job \(record.id) failed: \(failure.message)")
    setStatus(record, .failed(failure))
    advanceQueue(after: record.id)
  }

  private func setStatus(_ record: JobRecord, _ status: BackgroundAgentJobStatus) {
    record.status = status
    publishJobs()
  }

  private func updateActivity(jobId: UUID, activity: String) {
    guard let record = records[jobId], case .generating = record.status else { return }
    record.activity = activity
    publishJobs()
  }

  private func dismissTerminalJobs(projectPath: String) {
    let terminalIds = order.filter { id in
      guard let record = records[id] else { return false }
      return record.request.projectPath == projectPath && !record.status.isActive
    }
    for id in terminalIds {
      dismiss(jobId: id)
    }
  }

  private func publishJobs() {
    jobs = order.compactMap { id in
      guard let record = records[id] else { return nil }
      return BackgroundAgentJobSnapshot(
        id: record.id,
        request: record.request,
        status: record.status,
        createdAt: record.createdAt,
        startedAt: record.startedAt,
        changedFiles: record.changedFiles.map(\.relativePath),
        activityDescription: record.activity
      )
    }
  }
}
