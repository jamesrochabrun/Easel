//
//  BackgroundAgentJobServiceTests.swift
//  EaselChatTests
//

import EaselKit
import Foundation
import Testing
@testable import EaselChat

// MARK: - Test doubles

private struct StubError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

private actor MockAgentRunner: BackgroundAgentRunning {
  enum Behavior {
    case succeed
    case fail(Error)
    /// Blocks until cancel() is called, then throws CancellationError —
    /// models a long codex run whose result gets discarded.
    case hangUntilCancelled
  }

  private(set) var requests: [BackgroundAgentRunRequest] = []
  private(set) var cancelCount = 0
  private var behavior: Behavior
  private var cancelled = false

  init(behavior: Behavior) {
    self.behavior = behavior
  }

  func setBehavior(_ behavior: Behavior) {
    self.behavior = behavior
  }

  func run(
    _ request: BackgroundAgentRunRequest,
    onActivity: @escaping @Sendable (String) -> Void
  ) async throws -> BackgroundAgentRunResult {
    requests.append(request)
    switch behavior {
    case .succeed:
      onActivity("Editing index.html")
      return BackgroundAgentRunResult(rawOutput: "done")
    case .fail(let error):
      throw error
    case .hangUntilCancelled:
      while !cancelled {
        try? await Task.sleep(for: .milliseconds(5))
      }
      throw CancellationError()
    }
  }

  func cancel() {
    cancelled = true
    cancelCount += 1
  }
}

private actor MockShadowWorkspacing: ShadowWorkspacing {
  var changes: [ShadowFileChange]
  var createError: Error?
  private(set) var createdJobIds: [UUID] = []
  private(set) var cleanedJobIds: [UUID] = []
  private(set) var sweptKeeping: [Set<UUID>] = []

  init(changes: [ShadowFileChange] = [ShadowFileChange(relativePath: "index.html", kind: .modified)]) {
    self.changes = changes
  }

  func setChanges(_ changes: [ShadowFileChange]) {
    self.changes = changes
  }

  func create(projectPath: String, jobId: UUID) async throws -> ShadowWorkspace {
    if let createError { throw createError }
    createdJobIds.append(jobId)
    return ShadowWorkspace(
      jobId: jobId,
      projectPath: projectPath,
      rootPath: "\(projectPath)/.easel/tweaks/\(jobId.uuidString)/shadow",
      manifest: ["index.html": "baseline-hash"]
    )
  }

  func changedFiles(in workspace: ShadowWorkspace) async throws -> [ShadowFileChange] {
    changes
  }

  func cleanup(projectPath: String, jobId: UUID) async {
    cleanedJobIds.append(jobId)
  }

  func sweepStaleArtifacts(projectPath: String, keeping liveJobIds: Set<UUID>) async {
    sweptKeeping.append(liveJobIds)
  }
}

private actor MockApplyEngine: BackgroundJobApplying {
  /// Consumed one entry per driftedFiles call; empty list → no drift.
  var driftScript: [[String]]
  var postApplyDriftResult: [String] = []
  var applyError: Error?
  private(set) var applyCount = 0
  private(set) var undoCount = 0

  init(driftScript: [[String]] = []) {
    self.driftScript = driftScript
  }

  func setPostApplyDrift(_ drift: [String]) {
    postApplyDriftResult = drift
  }

  func driftedFiles(
    changes: [ShadowFileChange],
    manifest: [String: String],
    projectPath: String
  ) async -> [String] {
    driftScript.isEmpty ? [] : driftScript.removeFirst()
  }

  func apply(changes: [ShadowFileChange], workspace: ShadowWorkspace) async throws -> AppliedJobRecord {
    applyCount += 1
    if let applyError { throw applyError }
    return AppliedJobRecord(
      jobId: workspace.jobId,
      projectPath: workspace.projectPath,
      backupRoot: "\(workspace.projectPath)/.easel/tweaks/\(workspace.jobId.uuidString)/backup",
      appliedFiles: changes.map {
        AppliedFile(relativePath: $0.relativePath, kind: $0.kind, appliedHash: "applied-hash", hadBackup: true)
      }
    )
  }

  func undo(record: AppliedJobRecord) async throws {
    undoCount += 1
  }

  func postApplyDrift(record: AppliedJobRecord) async -> [String] {
    postApplyDriftResult
  }
}

private struct MockValidator: BackgroundJobValidating {
  var error: Error?

  func validate(
    shadowRoot: String,
    targetRelativePath: String,
    changedFiles: [String]
  ) async throws -> BackgroundJobValidationOutcome {
    if let error { throw error }
    return BackgroundJobValidationOutcome(schemaFileRelativePath: targetRelativePath, propNames: ["warmth"])
  }
}

@MainActor
private final class BusyFlag {
  var isBusy = false
}

// MARK: - Harness

@MainActor
private struct Harness {
  let service: BackgroundAgentJobService
  let runner: MockAgentRunner
  let workspace: MockShadowWorkspacing
  let applyEngine: MockApplyEngine
  let busy: BusyFlag

  init(
    runnerBehavior: MockAgentRunner.Behavior = .succeed,
    changes: [ShadowFileChange] = [ShadowFileChange(relativePath: "index.html", kind: .modified)],
    driftScript: [[String]] = [],
    validatorError: Error? = nil,
    runnerProviderError: Error? = nil
  ) {
    let runner = MockAgentRunner(behavior: runnerBehavior)
    let workspace = MockShadowWorkspacing(changes: changes)
    let applyEngine = MockApplyEngine(driftScript: driftScript)
    let busy = BusyFlag()

    self.runner = runner
    self.workspace = workspace
    self.applyEngine = applyEngine
    self.busy = busy
    self.service = BackgroundAgentJobService(
      runnerProvider: {
        if let runnerProviderError { throw runnerProviderError }
        return runner
      },
      validator: MockValidator(error: validatorError),
      isChatBusy: { [busy] _ in busy.isBusy },
      workspaceManager: workspace,
      applyEngine: applyEngine,
      generationTimeout: 5,
      idlePollInterval: .milliseconds(5)
    )
  }

  func job(_ id: UUID) -> BackgroundAgentJobSnapshot? {
    service.jobs.first { $0.id == id }
  }

  func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(5),
    condition: @MainActor () -> Bool
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
      if clock.now > deadline {
        throw StubError(message: "Timed out waiting for \(description)")
      }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func waitUntilAsync(
    _ description: String,
    timeout: Duration = .seconds(5),
    condition: () async -> Bool
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !(await condition()) {
      if clock.now > deadline {
        throw StubError(message: "Timed out waiting for \(description)")
      }
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}

private func makeRequest(
  projectPath: String = "/tmp/test-project",
  summary: String = "Ideas"
) -> BackgroundAgentJobRequest {
  BackgroundAgentJobRequest(
    kind: .tweaks,
    projectPath: projectPath,
    targetFileRelativePath: "index.html",
    displayFileName: "index.html",
    prompt: "Add tweakable controls to index.html",
    summary: summary
  )
}

// MARK: - Tests

@MainActor
struct BackgroundAgentJobServiceTests {

  @Test
  func happyPathAppliesAndReportsChangedFiles() async throws {
    let harness = Harness()
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("applied") {
      harness.job(jobId)?.status == .applied(undoAvailable: true)
    }

    let snapshot = try #require(harness.job(jobId))
    #expect(snapshot.changedFiles == ["index.html"])
    #expect(snapshot.startedAt != nil)

    // The agent ran against the shadow, never the real tree.
    let requests = await harness.runner.requests
    #expect(requests.count == 1)
    #expect(requests[0].workingDirectory.contains("/.easel/tweaks/"))
    let applyCount = await harness.applyEngine.applyCount
    #expect(applyCount == 1)
  }

  @Test
  func jobsRunFIFOOneAtATime() async throws {
    let harness = Harness(runnerBehavior: .hangUntilCancelled)
    let first = harness.service.submit(makeRequest())
    let second = harness.service.submit(makeRequest(summary: "second"))

    try await harness.waitUntil("first generating") {
      harness.job(first)?.status == .generating
    }
    #expect(harness.job(second)?.status == .queued)

    harness.service.cancel(jobId: first)
    await harness.runner.setBehavior(.succeed)

    try await harness.waitUntil("second applied") {
      harness.job(second)?.status == .applied(undoAvailable: true)
    }
    #expect(harness.job(first)?.status == .cancelled)
  }

  @Test
  func waitsForBusyChatThenApplies() async throws {
    let harness = Harness()
    harness.busy.isBusy = true
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("waiting to apply") {
      harness.job(jobId)?.status == .waitingToApply
    }
    let applyCountWhileBusy = await harness.applyEngine.applyCount
    #expect(applyCountWhileBusy == 0)

    harness.busy.isBusy = false
    try await harness.waitUntil("applied after idle") {
      harness.job(jobId)?.status == .applied(undoAvailable: true)
    }
  }

  @Test
  func driftAtCompletionBecomesConflict() async throws {
    let harness = Harness(driftScript: [["index.html"]])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("conflict") {
      harness.job(jobId)?.status == .conflict(driftedFiles: ["index.html"])
    }
    let applyCount = await harness.applyEngine.applyCount
    #expect(applyCount == 0)
  }

  @Test
  func driftAfterBusyWaitBecomesConflict() async throws {
    // First check (pre-wait) clean; final check before writes drifts.
    let harness = Harness(driftScript: [[], ["index.html"]])
    harness.busy.isBusy = true
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("waiting to apply") {
      harness.job(jobId)?.status == .waitingToApply
    }
    harness.busy.isBusy = false

    try await harness.waitUntil("conflict") {
      harness.job(jobId)?.status == .conflict(driftedFiles: ["index.html"])
    }
  }

  @Test
  func applyAnywaySkipsDriftCheckAndApplies() async throws {
    let harness = Harness(driftScript: [["index.html"], ["index.html"]])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("conflict") {
      if case .conflict = harness.job(jobId)?.status { return true }
      return false
    }

    harness.service.resolveConflict(jobId: jobId, resolution: .applyAnyway)
    try await harness.waitUntil("applied anyway") {
      harness.job(jobId)?.status == .applied(undoAvailable: true)
    }
  }

  @Test
  func regenerateOnLatestStartsFreshJobWithSameRequest() async throws {
    let harness = Harness(driftScript: [["index.html"]])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("conflict") {
      if case .conflict = harness.job(jobId)?.status { return true }
      return false
    }

    harness.service.resolveConflict(jobId: jobId, resolution: .regenerateOnLatest)

    // Old job is dismissed; a new one with the same request runs to applied.
    #expect(harness.job(jobId) == nil)
    try await harness.waitUntil("regenerated job applied") {
      harness.service.jobs.contains {
        $0.request == makeRequest() && $0.status == .applied(undoAvailable: true)
      }
    }
    let createdIds = await harness.workspace.createdJobIds
    #expect(createdIds.count == 2)
  }

  @Test
  func discardCancelsAndCleansUp() async throws {
    let harness = Harness(driftScript: [["index.html"]])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("conflict") {
      if case .conflict = harness.job(jobId)?.status { return true }
      return false
    }

    harness.service.resolveConflict(jobId: jobId, resolution: .discard)
    #expect(harness.job(jobId)?.status == .cancelled)
    try await harness.waitUntilAsync("cleanup") {
      await harness.workspace.cleanedJobIds.contains(jobId)
    }
  }

  @Test
  func cancelQueuedJobNeverRuns() async throws {
    let harness = Harness(runnerBehavior: .hangUntilCancelled)
    let first = harness.service.submit(makeRequest())
    let second = harness.service.submit(makeRequest(summary: "second"))

    try await harness.waitUntil("first generating") {
      harness.job(first)?.status == .generating
    }
    harness.service.cancel(jobId: second)
    #expect(harness.job(second)?.status == .cancelled)

    harness.service.cancel(jobId: first)
    try await harness.waitUntil("first cancelled") {
      harness.job(first)?.status == .cancelled
    }
    let requests = await harness.runner.requests
    #expect(requests.count == 1)
  }

  @Test
  func cancelRunningJobFlagsRunnerAndCleansShadowAfterRunReturns() async throws {
    let harness = Harness(runnerBehavior: .hangUntilCancelled)
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("generating") {
      harness.job(jobId)?.status == .generating
    }
    harness.service.cancel(jobId: jobId)

    // Status flips instantly; cleanup happens once the abandoned run exits.
    #expect(harness.job(jobId)?.status == .cancelled)
    try await harness.waitUntilAsync("runner cancelled") {
      await harness.runner.cancelCount == 1
    }
    try await harness.waitUntilAsync("shadow cleaned after run returned") {
      await harness.workspace.cleanedJobIds.contains(jobId)
    }
  }

  @Test
  func runnerFailureBecomesAgentFailed() async throws {
    let harness = Harness(runnerBehavior: .fail(StubError(message: "codex exploded")))
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("failed") {
      harness.job(jobId)?.status == .failed(.agentFailed("codex exploded"))
    }
  }

  @Test
  func timeoutBecomesTimedOutFailure() async throws {
    let harness = Harness(runnerBehavior: .fail(BackgroundAgentRunnerError.timedOut))
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("timed out") {
      harness.job(jobId)?.status == .failed(.timedOut)
    }
  }

  @Test
  func emptyDiffFailsValidation() async throws {
    let harness = Harness(changes: [])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("validation failed") {
      if case .failed(.validationFailed) = harness.job(jobId)?.status { return true }
      return false
    }
    let applyCount = await harness.applyEngine.applyCount
    #expect(applyCount == 0)
  }

  @Test
  func deletionOnlyDiffFailsValidation() async throws {
    let harness = Harness(changes: [ShadowFileChange(relativePath: "index.html", kind: .deleted)])
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("validation failed") {
      if case .failed(.validationFailed) = harness.job(jobId)?.status { return true }
      return false
    }
  }

  @Test
  func validatorErrorFailsValidationWithMessage() async throws {
    let harness = Harness(validatorError: StubError(message: "No dc_set_props schema found"))
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("validation failed") {
      harness.job(jobId)?.status == .failed(.validationFailed("No dc_set_props schema found"))
    }
  }

  @Test
  func runnerProviderErrorFailsJob() async throws {
    let harness = Harness(runnerProviderError: StubError(message: "Chat not initialized"))
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("failed") {
      harness.job(jobId)?.status == .failed(.agentFailed("Chat not initialized"))
    }
  }

  @Test
  func retryResubmitsFailedJob() async throws {
    let harness = Harness(runnerBehavior: .fail(StubError(message: "flaky")))
    let jobId = harness.service.submit(makeRequest())

    try await harness.waitUntil("failed") {
      if case .failed = harness.job(jobId)?.status { return true }
      return false
    }

    await harness.runner.setBehavior(.succeed)
    harness.service.retry(jobId: jobId)

    #expect(harness.job(jobId) == nil)
    try await harness.waitUntil("retried job applied") {
      harness.service.jobs.contains { $0.status == .applied(undoAvailable: true) }
    }
  }

  @Test
  func undoRespectsPostApplyDriftUnlessForced() async throws {
    let harness = Harness()
    let jobId = harness.service.submit(makeRequest())
    try await harness.waitUntil("applied") {
      harness.job(jobId)?.status == .applied(undoAvailable: true)
    }

    await harness.applyEngine.setPostApplyDrift(["index.html"])
    #expect(await harness.service.postApplyDriftedFiles(jobId: jobId) == ["index.html"])

    await harness.service.undo(jobId: jobId, force: false)
    #expect(harness.job(jobId)?.status == .applied(undoAvailable: true))
    let undoCountBlocked = await harness.applyEngine.undoCount
    #expect(undoCountBlocked == 0)

    await harness.service.undo(jobId: jobId, force: true)
    #expect(harness.job(jobId)?.status == .undone)
    let undoCount = await harness.applyEngine.undoCount
    #expect(undoCount == 1)
  }

  @Test
  func newSubmitAutoDismissesTerminalJobsForSameProject() async throws {
    let harness = Harness()
    let first = harness.service.submit(makeRequest())
    try await harness.waitUntil("first applied") {
      harness.job(first)?.status == .applied(undoAvailable: true)
    }

    let second = harness.service.submit(makeRequest(summary: "second"))
    #expect(harness.job(first) == nil)
    try await harness.waitUntil("second applied") {
      harness.job(second)?.status == .applied(undoAvailable: true)
    }
    #expect(harness.service.jobs.count == 1)
  }

  @Test
  func firstJobSweepsStaleArtifactsKeepingLiveIds() async throws {
    let harness = Harness()
    let jobId = harness.service.submit(makeRequest())
    try await harness.waitUntil("applied") {
      harness.job(jobId)?.status == .applied(undoAvailable: true)
    }

    let sweeps = await harness.workspace.sweptKeeping
    #expect(sweeps.count == 1)
    #expect(sweeps[0].contains(jobId))
  }
}
