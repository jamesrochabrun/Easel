//
//  ProjectResourceDirectoryChangeObserverTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselChat

struct ProjectResourceDirectoryChangeObserverTests {
  @Test
  func firstSnapshotDoesNotReportChange() async throws {
    let directory = try makeTemporaryProjectDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("resources/hero.png"))
    let observer = ProjectResourceDirectoryChangeObserver(projectPath: directory.path)

    #expect(!(await observer.hasChangedSinceLastSnapshot()))
  }

  @Test
  func addingGeneratedResourceReportsChange() async throws {
    let directory = try makeTemporaryProjectDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("resources/hero.png"))
    let observer = ProjectResourceDirectoryChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()

    try write("new image", to: directory.appendingPathComponent("resources/generated-market.png"))

    #expect(await observer.hasChangedSinceLastSnapshot())
    #expect(!(await observer.hasChangedSinceLastSnapshot()))
  }

  @Test
  func modifyingGeneratedResourceReportsChange() async throws {
    let directory = try makeTemporaryProjectDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let resourceURL = directory.appendingPathComponent("resources/hero.png")
    try write("initial", to: resourceURL)
    let observer = ProjectResourceDirectoryChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()

    try await Task.sleep(for: .milliseconds(20))
    try write("updated", to: resourceURL)

    #expect(await observer.hasChangedSinceLastSnapshot())
  }

  private func makeTemporaryProjectDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselResourceObserverTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.data(using: .utf8)?.write(to: url, options: .atomic)
  }
}
