//
//  StudioMCPConfiguration.swift
//  ClaudeCodeCore
//
//  How a chat session attaches Easel's bundled Studio MCP server.
//

import Foundation

/// Everything a runtime needs to attach the bundled `EaselMCPServer` to a
/// CLI session. Threaded from the app like `systemPromptPrefix`: built once
/// per session by the host app, handed to `ChatViewModel`, consumed by the
/// Claude and Codex runtimes at options-build time (so the environment can
/// carry the session id once one exists). `nil` means no Studio tools —
/// providers without MCP transport (`.arnes`, `.api`) always pass nil.
public struct StudioMCPConfiguration: Sendable, Equatable {
  /// Absolute path of the bundled `EaselMCPServer` executable.
  public let serverPath: String
  /// The project this session works on — the artifact routing key.
  public let projectPath: String
  /// Easel's Application Support directory, passed explicitly so the
  /// CLI-spawned server resolves the same queue/index directories as the app.
  public let appSupportDirectory: String
  /// System-prompt steering toward the Studio tools. Rides with the server
  /// attachment on purpose: guidance naming tools a session does not have
  /// misleads the model, so the runtimes only inject it alongside the tools —
  /// which also keeps it away from providers sharing a prefix (Arnes reuses
  /// the Codex developer instructions but has no MCP transport).
  public let agentGuidance: String?

  public init(
    serverPath: String,
    projectPath: String,
    appSupportDirectory: String,
    agentGuidance: String? = nil
  ) {
    self.serverPath = serverPath
    self.projectPath = projectPath
    self.appSupportDirectory = appSupportDirectory
    self.agentGuidance = agentGuidance
  }

  /// The server name both CLIs register the tools under (`mcp__easel__…`).
  public static let serverName = "easel"

  /// Environment baked into the server entry. Neither CLI inherits the app's
  /// environment into MCP servers, so provenance must ride the config itself.
  public func environment(provider: String, sessionId: String?) -> [String: String] {
    var env = [
      "EASEL_PROVIDER": provider,
      "EASEL_PROJECT_PATH": projectPath,
      "EASEL_APP_SUPPORT_DIR": appSupportDirectory,
    ]
    // The first turn of a session has no id yet (Easel spawns a fresh CLI
    // process per turn); the tools treat the session id as optional provenance.
    if let sessionId, !sessionId.isEmpty {
      env["EASEL_SESSION_ID"] = sessionId
    }
    return env
  }
}

/// Merges the Studio server into a user-provided MCP config file.
///
/// The Claude SDK prefers `mcpConfigPath` over inline `mcpServers`, so when
/// the user has their own config file, the Studio server must be merged into
/// a derived file rather than passed inline (which would be ignored) or
/// written into the user's file (which is theirs).
public enum StudioMCPConfigMerger {
  /// Returns the merged JSON (`{"mcpServers": {...user's..., "easel": {...}}}`).
  /// The user's entries win on any name collision other than `easel`.
  public static func mergedConfigData(
    userConfigData: Data?,
    serverPath: String,
    environment: [String: String]
  ) throws -> Data {
    var root: [String: Any] = [:]
    if let userConfigData,
       let parsed = try? JSONSerialization.jsonObject(with: userConfigData) as? [String: Any]
    {
      root = parsed
    }
    var servers = root["mcpServers"] as? [String: Any] ?? [:]
    servers[StudioMCPConfiguration.serverName] = [
      "command": serverPath,
      "args": ["mcp-server"],
      "env": environment,
    ]
    root["mcpServers"] = servers
    return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
  }

  /// Writes the merged config beside the app's other preferences and returns
  /// its path, or nil when writing failed (callers fall back to the user's
  /// own config so a Studio problem never breaks the session).
  public static func writeMergedConfig(
    userConfigPath: String,
    serverPath: String,
    environment: [String: String],
    outputDirectory: URL
  ) -> String? {
    let userData = FileManager.default.contents(atPath: (userConfigPath as NSString).expandingTildeInPath)
    guard let merged = try? mergedConfigData(
      userConfigData: userData,
      serverPath: serverPath,
      environment: environment
    ) else {
      return nil
    }
    let outputURL = outputDirectory.appendingPathComponent("easel-studio-mcp-config.json", isDirectory: false)
    do {
      try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
      try merged.write(to: outputURL, options: [.atomic])
      return outputURL.path
    } catch {
      return nil
    }
  }
}
