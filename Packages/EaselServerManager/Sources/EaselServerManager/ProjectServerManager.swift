//
//  ProjectServerManager.swift
//  EaselServerManager
//

import EaselKit
import Foundation
import OSLog

private let managerLog = Logger(
  subsystem: "com.easel.servermanager",
  category: "ProjectServerManager"
)

@Observable @MainActor
public final class ProjectServerManager: ServerManaging {

  // MARK: - Public State

  public private(set) var activeServers: [String: ProjectServer] = [:]

  // MARK: - Private State

  private var runningServers: [String: StaticFileServer] = [:]
  private var portAssignments: [String: UInt16]

  // MARK: - Init

  public init() {
    self.portAssignments = PortAllocator.loadAssignments()
  }

  // MARK: - ServerManaging

  public func startServer(
    for workingDirectory: String
  ) async throws -> ProjectServer {
    if let existing = activeServers[workingDirectory] {
      return existing
    }

    let port = PortAllocator.assignPort(
      for: workingDirectory,
      existingAssignments: portAssignments
    )
    portAssignments[workingDirectory] = port
    PortAllocator.saveAssignments(portAssignments)

    let server = try StaticFileServer(
      port: port,
      rootDirectory: workingDirectory
    )
    server.start()

    let projectServer = ProjectServer(
      workingDirectory: workingDirectory,
      port: port
    )

    runningServers[workingDirectory] = server
    activeServers[workingDirectory] = projectServer

    managerLog.info("Started server for \(workingDirectory) on port \(port)")

    return projectServer
  }

  public func stopServer(for workingDirectory: String) async {
    runningServers[workingDirectory]?.stop()
    runningServers.removeValue(forKey: workingDirectory)
    activeServers.removeValue(forKey: workingDirectory)
    PortAllocator.removeAssignment(
      for: workingDirectory,
      from: &portAssignments
    )

    managerLog.info("Stopped server for \(workingDirectory)")
  }

  public func stopAllServers() async {
    for (_, server) in runningServers {
      server.stop()
    }
    runningServers.removeAll()
    activeServers.removeAll()

    managerLog.info("All servers stopped")
  }

  public func serverURL(for workingDirectory: String) -> URL? {
    activeServers[workingDirectory]?.url
  }
}
