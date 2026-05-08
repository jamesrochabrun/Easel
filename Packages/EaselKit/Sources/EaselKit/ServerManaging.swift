//
//  ServerManaging.swift
//  EaselKit
//

import Foundation

/// Represents a running localhost server for a project directory.
public struct ProjectServer: Sendable, Equatable {
  public let workingDirectory: String
  public let port: UInt16
  public let url: URL

  public init(workingDirectory: String, port: UInt16) {
    self.workingDirectory = workingDirectory
    self.port = port
    self.url = URL(string: "http://localhost:\(port)")!
  }

  public init(workingDirectory: String, url: URL) {
    self.workingDirectory = workingDirectory
    self.port = UInt16(url.port ?? 0)
    self.url = url
  }
}

/// Manages per-project localhost servers with automatic port assignment.
@MainActor
public protocol ServerManaging: AnyObject {
  /// All currently running servers, keyed by working directory.
  var activeServers: [String: ProjectServer] { get }

  /// Starts a server for the given project directory.
  /// Returns the existing server if one is already running.
  func startServer(for workingDirectory: String) async throws -> ProjectServer

  /// Stops the server for the given project directory and frees the port.
  func stopServer(for workingDirectory: String) async

  /// Stops all running servers. Port assignments are preserved for restart.
  func stopAllServers() async

  /// Returns the server URL for a project, if running.
  func serverURL(for workingDirectory: String) -> URL?
}
