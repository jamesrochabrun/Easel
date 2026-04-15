//
//  ProjectServerManagerTests.swift
//  EaselServerManagerTests
//

@testable import EaselServerManager
import EaselKit
import Foundation
import Testing

@MainActor
@Suite
struct ProjectServerManagerTests {

  private func makeTempProject(name: String = "test-project") throws -> String {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("easel-tests")
      .appendingPathComponent(name)
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let indexHTML = "<html><body><h1>Hello</h1></body></html>"
    try indexHTML.write(
      to: dir.appendingPathComponent("index.html"),
      atomically: true,
      encoding: .utf8
    )
    return dir.path
  }

  private func cleanupDefaults() {
    UserDefaults.standard.removeObject(forKey: "easel.serverManager.portAssignments")
  }

  @Test
  func initialStateHasNoServers() {
    cleanupDefaults()
    let manager = ProjectServerManager()
    #expect(manager.activeServers.isEmpty)
  }

  @Test
  func startServerReturnsProjectServer() async throws {
    cleanupDefaults()
    let dir = try makeTempProject()
    let manager = ProjectServerManager()

    let server = try await manager.startServer(for: dir)
    #expect(server.port >= PortAllocator.basePort)
    #expect(server.workingDirectory == dir)
    #expect(server.url.absoluteString.contains("localhost"))

    await manager.stopAllServers()
  }

  @Test
  func startServerTwiceReturnsSameServer() async throws {
    cleanupDefaults()
    let dir = try makeTempProject()
    let manager = ProjectServerManager()

    let first = try await manager.startServer(for: dir)
    let second = try await manager.startServer(for: dir)
    #expect(first == second)

    await manager.stopAllServers()
  }

  @Test
  func multipleProjectsGetDifferentPorts() async throws {
    cleanupDefaults()
    let dir1 = try makeTempProject(name: "project-a")
    let dir2 = try makeTempProject(name: "project-b")
    let manager = ProjectServerManager()

    let server1 = try await manager.startServer(for: dir1)
    let server2 = try await manager.startServer(for: dir2)
    #expect(server1.port != server2.port)

    await manager.stopAllServers()
  }

  @Test
  func stopServerRemovesFromActive() async throws {
    cleanupDefaults()
    let dir = try makeTempProject()
    let manager = ProjectServerManager()

    _ = try await manager.startServer(for: dir)
    await manager.stopServer(for: dir)

    #expect(manager.activeServers.isEmpty)
    #expect(manager.serverURL(for: dir) == nil)
  }

  @Test
  func stopAllServersRemovesAll() async throws {
    cleanupDefaults()
    let dir1 = try makeTempProject(name: "proj-1")
    let dir2 = try makeTempProject(name: "proj-2")
    let manager = ProjectServerManager()

    _ = try await manager.startServer(for: dir1)
    _ = try await manager.startServer(for: dir2)
    await manager.stopAllServers()

    #expect(manager.activeServers.isEmpty)
  }

  @Test
  func serverURLReturnsNilForUnknownProject() {
    cleanupDefaults()
    let manager = ProjectServerManager()
    #expect(manager.serverURL(for: "/nonexistent") == nil)
  }

  @Test
  func serverURLReturnsURLForRunningServer() async throws {
    cleanupDefaults()
    let dir = try makeTempProject()
    let manager = ProjectServerManager()

    let server = try await manager.startServer(for: dir)
    #expect(manager.serverURL(for: dir) == server.url)

    await manager.stopAllServers()
  }
}
