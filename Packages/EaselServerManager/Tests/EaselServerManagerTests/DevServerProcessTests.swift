//
//  DevServerProcessTests.swift
//  EaselServerManagerTests
//

import Foundation
import Testing
@testable import EaselServerManager

@MainActor
struct DevServerProcessTests {

  @Test
  func throwsNoPackageJSONForMissingFile() async {
    let process = DevServerProcess(workingDirectory: "/nonexistent/path")
    await #expect(throws: DevServerError.self) {
      try await process.start(timeout: 5)
    }
  }

  @Test
  func throwsNoDevScriptForEmptyPackageJSON() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("DevServerProcessTests-\(UUID())")
    try FileManager.default.createDirectory(
      at: tmpDir, withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    // Write a package.json with no scripts
    let packageJSON = ["name": "test-project"]
    let data = try JSONSerialization.data(withJSONObject: packageJSON)
    try data.write(to: tmpDir.appendingPathComponent("package.json"))

    let process = DevServerProcess(workingDirectory: tmpDir.path)
    await #expect(throws: DevServerError.self) {
      try await process.start(timeout: 5)
    }
  }

  @Test
  func isNotRunningInitially() {
    let process = DevServerProcess(workingDirectory: "/tmp")
    #expect(!process.isRunning)
  }
}
