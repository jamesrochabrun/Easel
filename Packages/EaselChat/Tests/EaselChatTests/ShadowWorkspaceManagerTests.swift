//
//  ShadowWorkspaceManagerTests.swift
//  EaselChatTests
//

import EaselKit
import Foundation
import Testing
@testable import EaselChat

struct ShadowWorkspaceManagerTests {

  private func makeProject() throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("shadow-tests-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("node_modules/pkg"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent(".easel"), withIntermediateDirectories: true)
    try "<html>hello</html>".write(to: root.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    try "body { color: red }".write(to: root.appendingPathComponent("src/style.css"), atomically: true, encoding: .utf8)
    try "ignore me".write(to: root.appendingPathComponent("node_modules/pkg/index.js"), atomically: true, encoding: .utf8)
    try "metadata".write(to: root.appendingPathComponent(".easel/catalog.json"), atomically: true, encoding: .utf8)
    return root
  }

  @Test
  func createCopiesProjectExcludingIgnoredDirectories() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }
    let manager = ShadowWorkspaceManager()
    let jobId = UUID()

    let workspace = try await manager.create(projectPath: project.path, jobId: jobId)

    let shadow = URL(fileURLWithPath: workspace.rootPath)
    #expect(FileManager.default.fileExists(atPath: shadow.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: shadow.appendingPathComponent("src/style.css").path))
    #expect(!FileManager.default.fileExists(atPath: shadow.appendingPathComponent("node_modules").path))
    #expect(!FileManager.default.fileExists(atPath: shadow.appendingPathComponent(".easel").path))

    // Manifest covers exactly the copied files with correct hashes.
    #expect(Set(workspace.manifest.keys) == ["index.html", "src/style.css"])
    let expected = FileContentHasher.sha256(of: Data("<html>hello</html>".utf8))
    #expect(workspace.manifest["index.html"] == expected)

    // The shadow lives inside .easel so observers never see it.
    #expect(workspace.rootPath.contains("/.easel/tweaks/\(jobId.uuidString)/"))
  }

  @Test
  func changedFilesClassifiesModifiedCreatedAndDeleted() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }
    let manager = ShadowWorkspaceManager()

    let workspace = try await manager.create(projectPath: project.path, jobId: UUID())
    let shadow = URL(fileURLWithPath: workspace.rootPath)

    try "<html>tweaked</html>".write(to: shadow.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    try "new file".write(to: shadow.appendingPathComponent("src/new.js"), atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: shadow.appendingPathComponent("src/style.css"))

    let changes = try await manager.changedFiles(in: workspace)

    #expect(changes == [
      ShadowFileChange(relativePath: "index.html", kind: .modified),
      ShadowFileChange(relativePath: "src/new.js", kind: .created),
      ShadowFileChange(relativePath: "src/style.css", kind: .deleted),
    ])
  }

  @Test
  func changedFilesIsEmptyWhenUntouched() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }
    let manager = ShadowWorkspaceManager()

    let workspace = try await manager.create(projectPath: project.path, jobId: UUID())
    let changes = try await manager.changedFiles(in: workspace)
    #expect(changes.isEmpty)
  }

  @Test
  func cleanupRemovesOnlyTheJobDirectory() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }
    let manager = ShadowWorkspaceManager()
    let jobA = UUID()
    let jobB = UUID()
    _ = try await manager.create(projectPath: project.path, jobId: jobA)
    _ = try await manager.create(projectPath: project.path, jobId: jobB)

    await manager.cleanup(projectPath: project.path, jobId: jobA)

    let artifacts = ShadowWorkspaceManager.artifactsRootURL(projectPath: project.path)
    #expect(!FileManager.default.fileExists(atPath: artifacts.appendingPathComponent(jobA.uuidString).path))
    #expect(FileManager.default.fileExists(atPath: artifacts.appendingPathComponent(jobB.uuidString).path))
    #expect(FileManager.default.fileExists(atPath: project.appendingPathComponent("index.html").path))
  }

  @Test
  func sweepPreservesLiveJobsAndRemovesStaleOnes() async throws {
    let project = try makeProject()
    defer { try? FileManager.default.removeItem(at: project) }
    let manager = ShadowWorkspaceManager()
    let live = UUID()
    let stale = UUID()
    _ = try await manager.create(projectPath: project.path, jobId: live)
    _ = try await manager.create(projectPath: project.path, jobId: stale)

    await manager.sweepStaleArtifacts(projectPath: project.path, keeping: [live])

    let artifacts = ShadowWorkspaceManager.artifactsRootURL(projectPath: project.path)
    #expect(FileManager.default.fileExists(atPath: artifacts.appendingPathComponent(live.uuidString).path))
    #expect(!FileManager.default.fileExists(atPath: artifacts.appendingPathComponent(stale.uuidString).path))
  }
}
