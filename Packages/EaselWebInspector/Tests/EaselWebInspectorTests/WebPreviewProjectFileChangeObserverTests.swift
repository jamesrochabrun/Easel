//
//  WebPreviewProjectFileChangeObserverTests.swift
//  EaselWebInspectorTests
//

import Foundation
import Testing
@testable import EaselWebInspector

@Suite("WebPreviewProjectFileChangeObserver")
struct WebPreviewProjectFileChangeObserverTests {
  @Test("First snapshot does not report a change")
  func firstSnapshotDoesNotReportChange() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("index.html"))
    let observer = WebPreviewProjectFileChangeObserver(projectPath: directory.path)

    let changed = await observer.hasChangedSinceLastSnapshot()

    #expect(!changed)
  }

  @Test("File edits report one change")
  func fileEditsReportOneChange() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("index.html")
    try write("initial", to: fileURL)
    let observer = WebPreviewProjectFileChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()

    try write("changed content", to: fileURL)

    #expect(await observer.hasChangedSinceLastSnapshot())
    #expect(!(await observer.hasChangedSinceLastSnapshot()))
  }

  @Test("Ignored dependency folders do not report changes")
  func ignoredDependencyFoldersDoNotReportChanges() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("index.html"))
    let observer = WebPreviewProjectFileChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()

    let dependencyFile = directory
      .appendingPathComponent("node_modules", isDirectory: true)
      .appendingPathComponent("library.js")
    try write("dependency", to: dependencyFile)

    #expect(!(await observer.hasChangedSinceLastSnapshot()))
  }

  @Test("Ignored generated output folders do not report changes")
  func ignoredGeneratedOutputFoldersDoNotReportChanges() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("index.html"))
    let observer = WebPreviewProjectFileChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()

    try write("bundle", to: directory.appendingPathComponent("dist/assets/main.js"))
    try write("cache", to: directory.appendingPathComponent(".next/cache/app.json"))
    try write("coverage", to: directory.appendingPathComponent("coverage/report.json"))

    #expect(!(await observer.hasChangedSinceLastSnapshot()))
  }

  @Test("Snapshot excludes generated output folders")
  func snapshotExcludesGeneratedOutputFolders() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    try write("initial", to: directory.appendingPathComponent("index.html"))
    try write("bundle", to: directory.appendingPathComponent("dist/assets/main.js"))
    try write("cache", to: directory.appendingPathComponent(".next/cache/app.json"))

    let snapshot = WebPreviewProjectFileSnapshot.snapshot(projectPath: directory.path)

    #expect(snapshot.files["index.html"] != nil)
    #expect(snapshot.files["dist/assets/main.js"] == nil)
    #expect(snapshot.files[".next/cache/app.json"] == nil)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselWebInspectorTests-\(UUID().uuidString)", isDirectory: true)
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
