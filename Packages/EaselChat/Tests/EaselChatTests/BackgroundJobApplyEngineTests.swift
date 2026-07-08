//
//  BackgroundJobApplyEngineTests.swift
//  EaselChatTests
//

import EaselKit
import Foundation
import Testing
@testable import EaselChat

struct BackgroundJobApplyEngineTests {

  private struct Fixture {
    let project: URL
    let workspace: ShadowWorkspace
    let manager: ShadowWorkspaceManager
  }

  /// A project whose shadow has index.html modified and assets/new.bin created.
  private func makeAppliedFixture() async throws -> Fixture {
    let project = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("apply-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try "<html>original</html>".write(to: project.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

    let manager = ShadowWorkspaceManager()
    let workspace = try await manager.create(projectPath: project.path, jobId: UUID())
    let shadow = URL(fileURLWithPath: workspace.rootPath)
    try "<html>tweaked</html>".write(to: shadow.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: shadow.appendingPathComponent("assets"), withIntermediateDirectories: true)
    try Data([0x00, 0xFF, 0x10, 0x80]).write(to: shadow.appendingPathComponent("assets/new.bin"))
    return Fixture(project: project, workspace: workspace, manager: manager)
  }

  private var appliedChanges: [ShadowFileChange] {
    [
      ShadowFileChange(relativePath: "index.html", kind: .modified),
      ShadowFileChange(relativePath: "assets/new.bin", kind: .created),
    ]
  }

  @Test
  func noDriftWhenRealTreeUntouched() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    let drifted = await engine.driftedFiles(
      changes: appliedChanges,
      manifest: fixture.workspace.manifest,
      projectPath: fixture.project.path
    )
    #expect(drifted.isEmpty)
  }

  @Test
  func detectsDriftOnModifiedAndCreatedFiles() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    // Chat agent edited the same file during generation…
    try "<html>chat edit</html>".write(
      to: fixture.project.appendingPathComponent("index.html"), atomically: true, encoding: .utf8
    )
    // …and something created the file the job wants to create.
    try FileManager.default.createDirectory(
      at: fixture.project.appendingPathComponent("assets"), withIntermediateDirectories: true
    )
    try Data([0x01]).write(to: fixture.project.appendingPathComponent("assets/new.bin"))

    let drifted = await engine.driftedFiles(
      changes: appliedChanges,
      manifest: fixture.workspace.manifest,
      projectPath: fixture.project.path
    )
    #expect(drifted == ["assets/new.bin", "index.html"])
  }

  @Test
  func deletedBaselineFileCountsAsDrift() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    try FileManager.default.removeItem(at: fixture.project.appendingPathComponent("index.html"))

    let drifted = await engine.driftedFiles(
      changes: appliedChanges,
      manifest: fixture.workspace.manifest,
      projectPath: fixture.project.path
    )
    #expect(drifted == ["index.html"])
  }

  @Test
  func applyBacksUpWritesAndReportsHashes() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    let record = try await engine.apply(changes: appliedChanges, workspace: fixture.workspace)

    // Real tree now carries the shadow content, binary included.
    let html = try String(contentsOf: fixture.project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(html == "<html>tweaked</html>")
    let binary = try Data(contentsOf: fixture.project.appendingPathComponent("assets/new.bin"))
    #expect(binary == Data([0x00, 0xFF, 0x10, 0x80]))

    // Backup captured the pre-apply version of the modified file only.
    let backup = URL(fileURLWithPath: record.backupRoot)
    let backedUp = try String(contentsOf: backup.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(backedUp == "<html>original</html>")

    #expect(record.appliedFiles.count == 2)
    let modified = try #require(record.appliedFiles.first { $0.relativePath == "index.html" })
    let created = try #require(record.appliedFiles.first { $0.relativePath == "assets/new.bin" })
    #expect(modified.hadBackup)
    #expect(!created.hadBackup)
    #expect(modified.appliedHash == FileContentHasher.sha256(of: Data("<html>tweaked</html>".utf8)))
  }

  @Test
  func undoRestoresBackupsAndDeletesCreatedFiles() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    let record = try await engine.apply(changes: appliedChanges, workspace: fixture.workspace)
    try await engine.undo(record: record)

    let html = try String(contentsOf: fixture.project.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(html == "<html>original</html>")
    #expect(!FileManager.default.fileExists(atPath: fixture.project.appendingPathComponent("assets/new.bin").path))
  }

  @Test
  func postApplyDriftDetectsLaterEdits() async throws {
    let fixture = try await makeAppliedFixture()
    defer { try? FileManager.default.removeItem(at: fixture.project) }
    let engine = BackgroundJobApplyEngine()

    let record = try await engine.apply(changes: appliedChanges, workspace: fixture.workspace)

    var drift = await engine.postApplyDrift(record: record)
    #expect(drift.isEmpty)

    try "<html>edited after apply</html>".write(
      to: fixture.project.appendingPathComponent("index.html"), atomically: true, encoding: .utf8
    )
    drift = await engine.postApplyDrift(record: record)
    #expect(drift == ["index.html"])
  }
}
