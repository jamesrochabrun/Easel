import EaselStudioCore
import Foundation
import Testing

@testable import EaselStudio

@Suite("StudioSQLitePersistence")
struct StudioSQLitePersistenceTests {
  private func makeStore() throws -> (StudioSQLitePersistence, URL) {
    let root = try temporaryStudioRoot()
    let store = StudioSQLitePersistence(
      databaseURL: root.appendingPathComponent("studio.sqlite", isDirectory: false)
    )
    return (store, root)
  }

  @Test("A saved record round-trips with its payload intact")
  func roundTrip() async throws {
    let (store, root) = try makeStore()
    defer { try? FileManager.default.removeItem(at: root) }

    let artifact = makeStudioCanvas()
    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: artifact, projectPath: "/tmp/project/", sessionId: "s1")
    )

    let records = try await store.getStudioArtifacts(forProjectPath: "/tmp/project")
    #expect(records.count == 1)
    #expect(records.first?.projectPath == "/tmp/project")
    #expect(records.first?.provider == "claude")
    #expect(try records.first?.decodedArtifact() == artifact)
  }

  @Test("Saving the same id again replaces the row — re-file upserts")
  func upsertOnId() async throws {
    let (store, root) = try makeStore()
    defer { try? FileManager.default.removeItem(at: root) }

    let first = makeStudioCanvas()
    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: first, projectPath: "/tmp/project", sessionId: "s1")
    )
    let refiled = makeStudioCanvas(title: "Primary button v2", revision: 2)
    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: refiled, projectPath: "/tmp/project", sessionId: "s2")
    )

    let records = try await store.getAllStudioArtifacts()
    #expect(records.count == 1)
    #expect(try records.first?.decodedArtifact().title == "Primary button v2")
    #expect(records.first?.sessionId == "s2")
  }

  @Test("Delete by id and delete-all-for-project remove only their rows")
  func deletes() async throws {
    let (store, root) = try makeStore()
    defer { try? FileManager.default.removeItem(at: root) }

    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: makeStudioCanvas(id: "a"), projectPath: "/p1", sessionId: "s")
    )
    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: makeStudioCanvas(id: "b"), projectPath: "/p1", sessionId: "s")
    )
    try await store.saveStudioArtifact(
      StudioArtifactRecord(artifact: makeStudioDocument(id: "c"), projectPath: "/p2", sessionId: "s")
    )

    try await store.deleteStudioArtifact(id: "a")
    #expect(try await store.getStudioArtifacts(forProjectPath: "/p1").map(\.id) == ["b"])

    try await store.deleteAllStudioArtifacts(forProjectPath: "/p1")
    #expect(try await store.getStudioArtifacts(forProjectPath: "/p1").isEmpty)
    #expect(try await store.getStudioArtifacts(forProjectPath: "/p2").map(\.id) == ["c"])
  }

  @Test("Reopening the same database file sees earlier writes")
  func persistsAcrossInstances() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("studio.sqlite", isDirectory: false)

    let first = StudioSQLitePersistence(databaseURL: url)
    try await first.saveStudioArtifact(
      StudioArtifactRecord(artifact: makeStudioDocument(), projectPath: "/p", sessionId: "s")
    )

    let second = StudioSQLitePersistence(databaseURL: url)
    #expect(try await second.getAllStudioArtifacts().count == 1)
  }
}
