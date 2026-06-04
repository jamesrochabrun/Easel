//
//  SlideDeckProjectFileChangeObserverTests.swift
//  EaselSlidesTests
//

import Foundation
import Testing
@testable import EaselSlides

@Suite("SlideDeckProjectFileChangeObserver")
struct SlideDeckProjectFileChangeObserverTests {
  @Test
  func firstSnapshotDoesNotReportChange() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try write("initial", to: directory.appendingPathComponent("index.html"))

    let observer = SlideDeckProjectFileChangeObserver(projectPath: directory.path)

    #expect(await observer.hasChangedSinceLastSnapshot() == false)
  }

  @Test
  func modifyingProjectFileReportsChange() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("index.html")
    try write("initial", to: fileURL)

    let observer = SlideDeckProjectFileChangeObserver(projectPath: directory.path)
    _ = await observer.hasChangedSinceLastSnapshot()
    try write("updated body", to: fileURL)

    #expect(await observer.hasChangedSinceLastSnapshot())
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("SlideDeckProjectFileChangeObserverTests-\(UUID().uuidString)", isDirectory: true)
  }

  private func write(_ string: String, to url: URL) throws {
    try string.data(using: .utf8)?.write(to: url)
  }
}
