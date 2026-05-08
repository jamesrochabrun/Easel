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

  private var runningProcesses: [String: DevServerProcess] = [:]

  // MARK: - Init

  public init() {}

  // MARK: - ServerManaging

  public func startServer(
    for workingDirectory: String
  ) async throws -> ProjectServer {
    // Return existing server if running
    if let existing = activeServers[workingDirectory] {
      let process = runningProcesses[workingDirectory]
      if process?.isRunning == true {
        managerLog.info("Reusing running server for \(workingDirectory)")
        return existing
      }
      // Process died — clean up and restart
      managerLog.info("Server process died for \(workingDirectory), restarting")
      runningProcesses.removeValue(forKey: workingDirectory)
      activeServers.removeValue(forKey: workingDirectory)
    }

    let devProcess = DevServerProcess(workingDirectory: workingDirectory)
    runningProcesses[workingDirectory] = devProcess

    let detectedURL: URL
    do {
      detectedURL = try await devProcess.start()
    } catch {
      runningProcesses.removeValue(forKey: workingDirectory)
      managerLog.error("Failed to start dev server for \(workingDirectory): \(error.localizedDescription)")
      throw error
    }

    let projectServer = ProjectServer(
      workingDirectory: workingDirectory,
      url: detectedURL
    )
    activeServers[workingDirectory] = projectServer

    managerLog.info("Dev server ready for \(workingDirectory) at \(detectedURL.absoluteString)")
    return projectServer
  }

  public func stopServer(for workingDirectory: String) async {
    runningProcesses[workingDirectory]?.stop()
    runningProcesses.removeValue(forKey: workingDirectory)
    activeServers.removeValue(forKey: workingDirectory)
    managerLog.info("Stopped server for \(workingDirectory)")
  }

  public func stopAllServers() async {
    for (_, process) in runningProcesses {
      process.stop()
    }
    runningProcesses.removeAll()
    activeServers.removeAll()
    managerLog.info("All servers stopped")
  }

  public func serverURL(for workingDirectory: String) -> URL? {
    activeServers[workingDirectory]?.url
  }
}
