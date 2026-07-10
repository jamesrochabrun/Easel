import EaselKit
import Foundation
import Testing
@testable import EaselChat

@Suite("TweakWorkspaceCoordinator")
struct TweakWorkspaceCoordinatorTests {
  @Test func appliesGeneratedFileWhenTargetIsUnchanged() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data("after".utf8).write(to: transaction.workingFileURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .applied)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "after")
  }

  @Test func reportsNoChangesWithoutWritingTarget() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .noChanges)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "before")
  }

  @Test func preservesConcurrentTargetEdit() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data("agent edit".utf8).write(to: transaction.workingFileURL)
    try Data("main chat edit".utf8).write(to: fixture.targetURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .conflict)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "main chat edit")
  }

  private func makeFixture(contents: String) throws -> Fixture {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("TweakWorkspaceCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    let projectURL = rootURL.appendingPathComponent("project", isDirectory: true)
    let temporaryURL = rootURL.appendingPathComponent("tasks", isDirectory: true)
    try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    let targetURL = projectURL.appendingPathComponent("index.html")
    try Data(contents.utf8).write(to: targetURL)
    return Fixture(rootURL: rootURL, temporaryURL: temporaryURL, targetURL: targetURL)
  }
}

private struct Fixture {
  let rootURL: URL
  let temporaryURL: URL
  let targetURL: URL
}
