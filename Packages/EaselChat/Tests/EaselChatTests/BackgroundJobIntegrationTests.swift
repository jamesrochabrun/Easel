//
//  BackgroundJobIntegrationTests.swift
//  EaselChatTests
//
//  End-to-end pipeline tests with the REAL shadow-workspace manager and
//  apply engine on a real temp project — only the agent run is faked (it
//  edits the shadow file the way a headless CLI run would). Covers the
//  full apply loop and the drift-conflict → apply-anyway → undo story.
//

import EaselKit
import Foundation
import Testing
@testable import EaselChat

// MARK: - Doubles

/// "Agent" that instruments the target file inside the shadow workspace.
private struct FileEditingRunner: BackgroundAgentRunning {
  let relativePath: String
  let newContent: String
  /// Ran just before editing — used to simulate a concurrent chat edit.
  let beforeEditing: (@Sendable () -> Void)?

  func run(
    _ request: BackgroundAgentRunRequest,
    onActivity: @escaping @Sendable (String) -> Void
  ) async throws -> BackgroundAgentRunResult {
    beforeEditing?()
    onActivity("Editing \(relativePath)")
    let target = URL(fileURLWithPath: request.workingDirectory).appendingPathComponent(relativePath)
    try newContent.write(to: target, atomically: true, encoding: .utf8)
    return BackgroundAgentRunResult(rawOutput: "ok")
  }

  func cancel() async {}
}

/// Stand-in for the Canvas-backed validator (unit-tested in EaselWebInspector):
/// accepts any changed file containing a dc_set_props call.
private struct ContainsSchemaValidator: BackgroundJobValidating {
  func validate(
    shadowRoot: String,
    targetRelativePath: String,
    changedFiles: [String]
  ) async throws -> BackgroundJobValidationOutcome {
    for relativePath in [targetRelativePath] + changedFiles {
      let url = URL(fileURLWithPath: shadowRoot).appendingPathComponent(relativePath)
      if let source = try? String(contentsOf: url, encoding: .utf8), source.contains("dc_set_props") {
        return BackgroundJobValidationOutcome(schemaFileRelativePath: relativePath, propNames: ["warmth"])
      }
    }
    throw StubValidationError()
  }
}

private struct StubValidationError: LocalizedError {
  var errorDescription: String? { "No dc_set_props schema found" }
}

// MARK: - Tests

@MainActor
struct BackgroundJobIntegrationTests {

  private static let originalHTML = "<html><body>original</body></html>"
  private static let instrumentedHTML = """
    <html><body>
    <script>
      dc_set_props({ "warmth": { "label": "Warmth", "type": "slider", "value": 50 } });
      function render() {}
      dc_on_props_changed = render;
      render();
    </script>
    </body></html>
    """

  private func makeProject() throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("bg-integration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Self.originalHTML.write(to: root.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    return root
  }

  private func makeService(project: URL, runner: FileEditingRunner) -> BackgroundAgentJobService {
    BackgroundAgentJobService(
      runnerProvider: { runner },
      validator: ContainsSchemaValidator(),
      isChatBusy: { _ in false },
      idlePollInterval: .milliseconds(5)
    )
  }

  private func makeRequest(project: URL) -> BackgroundAgentJobRequest {
    BackgroundAgentJobRequest(
      kind: .tweaks,
      projectPath: project.path,
      targetFileRelativePath: "index.html",
      displayFileName: "index.html",
      prompt: "Add tweakable controls to index.html",
      summary: "Ideas"
    )
  }

  private func waitForStatus(
    _ service: BackgroundAgentJobService,
    jobId: UUID,
    timeout: Duration = .seconds(10),
    where predicate: @escaping (BackgroundAgentJobStatus) -> Bool
  ) async throws -> BackgroundAgentJobSnapshot {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
      if let job = service.jobs.first(where: { $0.id == jobId }), predicate(job.status) {
        return job
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    throw StubValidationError()
  }

  @Test
  func fullPipelineAppliesShadowEditsToRealProjectAndUndoes() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }

    let runner = FileEditingRunner(
      relativePath: "index.html",
      newContent: Self.instrumentedHTML,
      beforeEditing: nil
    )
    let service = makeService(project: project, runner: runner)
    let jobId = service.submit(makeRequest(project: project))

    let applied = try await waitForStatus(service, jobId: jobId) {
      $0 == .applied(undoAvailable: true)
    }
    #expect(applied.changedFiles == ["index.html"])

    // The real project file now carries the instrumented content.
    let projectHTML = try String(contentsOf: project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(projectHTML == Self.instrumentedHTML)

    // Undo restores the original.
    await service.undo(jobId: jobId, force: false)
    let restored = try String(contentsOf: project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(restored == Self.originalHTML)
    #expect(service.jobs.first { $0.id == jobId }?.status == .undone)
  }

  @Test
  func concurrentRealTreeEditSurfacesConflictAndApplyAnywayIsUndoable() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }

    // While the "agent" generates, the chat agent edits the same real file.
    let chatEditedHTML = "<html><body>chat edit</body></html>"
    let projectPath = project.path
    let runner = FileEditingRunner(
      relativePath: "index.html",
      newContent: Self.instrumentedHTML,
      beforeEditing: {
        try? chatEditedHTML.write(
          to: URL(fileURLWithPath: projectPath).appendingPathComponent("index.html"),
          atomically: true,
          encoding: .utf8
        )
      }
    )
    let service = makeService(project: project, runner: runner)
    let jobId = service.submit(makeRequest(project: project))

    let conflicted = try await waitForStatus(service, jobId: jobId) {
      if case .conflict = $0 { return true }
      return false
    }
    #expect(conflicted.status == .conflict(driftedFiles: ["index.html"]))

    // Apply anyway overwrites the chat edit…
    service.resolveConflict(jobId: jobId, resolution: .applyAnyway)
    _ = try await waitForStatus(service, jobId: jobId) {
      $0 == .applied(undoAvailable: true)
    }
    let appliedHTML = try String(contentsOf: project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(appliedHTML == Self.instrumentedHTML)

    // …and undo restores what the chat agent wrote, not the stale original.
    await service.undo(jobId: jobId, force: false)
    let restored = try String(contentsOf: project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(restored == chatEditedHTML)
  }

  @Test
  func artifactsLiveUnderEaselAndAreCleanedOnDismiss() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }

    let runner = FileEditingRunner(
      relativePath: "index.html",
      newContent: Self.instrumentedHTML,
      beforeEditing: nil
    )
    let service = makeService(project: project, runner: runner)
    let jobId = service.submit(makeRequest(project: project))
    _ = try await waitForStatus(service, jobId: jobId) {
      $0 == .applied(undoAvailable: true)
    }

    // Artifacts (shadow + backup) are kept for undo under .easel/tweaks.
    let jobDir = project
      .appendingPathComponent(".easel/tweaks")
      .appendingPathComponent(jobId.uuidString)
    #expect(FileManager.default.fileExists(atPath: jobDir.path))

    service.dismiss(jobId: jobId)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while FileManager.default.fileExists(atPath: jobDir.path), clock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(!FileManager.default.fileExists(atPath: jobDir.path))
    #expect(service.jobs.isEmpty)
  }
}
