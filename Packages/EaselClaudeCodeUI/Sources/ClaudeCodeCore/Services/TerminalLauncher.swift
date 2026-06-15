//
//  TerminalLauncher.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/24/24.
//

import Foundation
import AppKit
import ClaudeCodeSDK
import CodexSDK

/// Helper object to handle launching Terminal with Claude sessions
public struct TerminalLauncher {

  public static func launchLocalAgent(_ request: LocalAgentLaunchRequest) async throws {
    let scriptContent = try localAgentScriptContent(for: request)
    let scriptURL = try writeLaunchScript(content: scriptContent, prefix: "easel_agent")
    let opened = await MainActor.run {
      NSWorkspace.shared.open(scriptURL)
    }

    guard opened else {
      try? FileManager.default.removeItem(at: scriptURL)
      throw LocalAgentLaunchError.terminalOpenFailed
    }

    Task {
      try? await Task.sleep(for: .seconds(5))
      try? FileManager.default.removeItem(at: scriptURL)
    }
  }

  static func localAgentScriptContent(for request: LocalAgentLaunchRequest) throws -> String {
    let command = try localAgentShellCommand(for: request)
    let exports = environmentExports(for: request.environment)
    let lines = [
      "#!/bin/bash",
      exports.isEmpty ? nil : exports,
      command
    ].compactMap { $0 }

    return lines.joined(separator: "\n") + "\n"
  }

  static func localAgentShellCommand(for request: LocalAgentLaunchRequest) throws -> String {
    let workingDirectory = request.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !workingDirectory.isEmpty else {
      throw LocalAgentLaunchError.missingWorkingDirectory
    }

    guard let escapedWorkingDirectory = shellEscapeSingleQuoted(workingDirectory) else {
      throw LocalAgentLaunchError.invalidShellValue("Working directory")
    }

    let commandName = normalizedCommand(request.command, provider: request.provider)
    let executablePath: String?
    switch request.provider {
    case .codex:
      executablePath = findCodexExecutable(
        command: commandName,
        additionalPaths: request.additionalPaths
      )
    case .claude:
      executablePath = findClaudeExecutable(
        command: commandName,
        additionalPaths: request.additionalPaths
      )
    }

    guard let executablePath else {
      throw LocalAgentLaunchError.executableNotFound(commandName)
    }
    guard let escapedExecutablePath = shellEscapeSingleQuoted(executablePath) else {
      throw LocalAgentLaunchError.invalidShellValue("Executable path")
    }

    let joinedArguments = localAgentArguments(for: request)
      .map(shellEscapeSingleQuotedAllowingNewlines)
      .joined(separator: " ")

    if joinedArguments.isEmpty {
      return "cd \(escapedWorkingDirectory) && exec \(escapedExecutablePath)"
    }

    return "cd \(escapedWorkingDirectory) && exec \(escapedExecutablePath) \(joinedArguments)"
  }

  static func localAgentArguments(for request: LocalAgentLaunchRequest) -> [String] {
    switch request.provider {
    case .codex:
      var arguments: [String] = []
      if let model = normalizedOptionalArgument(request.codexModel) {
        arguments += ["--model", model]
      }
      arguments.append(contentsOf: request.extraArguments)
      if let prompt = normalizedOptionalArgument(request.prompt) {
        arguments.append(prompt)
      }
      return arguments

    case .claude:
      if let prompt = normalizedOptionalArgument(request.prompt) {
        return [prompt]
      }
      return []
    }
  }
  
  /// Launches Terminal with a Claude session resume command
  /// - Parameters:
  ///   - sessionId: The session ID to resume
  ///   - claudeClient: The Claude client with configuration
  ///   - projectPath: The project path to change to before resuming
  /// - Returns: An error if launching fails, nil on success
  public static func launchTerminalWithSession(
    _ sessionId: String,
    claudeClient: ClaudeCode,
    projectPath: String
  ) -> Error? {
    // Get the claude command from configuration
    let claudeCommand = claudeClient.configuration.command
    
    // Find the full path to the claude executable
    guard let claudeExecutablePath = findClaudeExecutable(
      command: claudeCommand,
      additionalPaths: claudeClient.configuration.additionalPaths
    ) else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find '\(claudeCommand)' command. Please ensure Claude Code CLI is installed."]
      )
    }
    
    // Escape paths for shell
    let escapedPath = projectPath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedClaudePath = claudeExecutablePath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedSessionId = sessionId.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    
    // Construct the command
    var command = ""
    if !projectPath.isEmpty {
      command = "cd \"\(escapedPath)\" && \"\(escapedClaudePath)\" -r \"\(escapedSessionId)\""
    } else {
      command = "\"\(escapedClaudePath)\" -r \"\(escapedSessionId)\""
    }
    
    // Create a temporary script file
    let tempDir = NSTemporaryDirectory()
    let scriptPath = (tempDir as NSString).appendingPathComponent("claude_resume_\(UUID().uuidString).command")
    
    // Create the script content
    let scriptContent = """
    #!/bin/bash
    \(command)
    """
    
    do {
      // Write the script to file
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      
      // Make it executable
      let attributes = [FileAttributeKey.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
      
      // Open the script with Terminal
      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)
      
      // Clean up the script file after a delay
      Task {
        try? await Task.sleep(for: .seconds(5))
        try? FileManager.default.removeItem(atPath: scriptPath)
      }
      
      return nil
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Terminal: \(error.localizedDescription)"]
      )
    }
  }
  
  /// Finds the full path to the Claude executable
  /// - Parameters:
  ///   - command: The command name to search for (e.g., "claude")
  ///   - additionalPaths: Additional paths to search from configuration
  /// - Returns: The full path to the executable if found, nil otherwise
  public static func findClaudeExecutable(
    command: String,
    additionalPaths: [String]?
  ) -> String? {
    findExecutable(command: command, additionalPaths: additionalPaths)
  }

  /// Finds the full path to the Codex executable, preferring local installs.
  /// - Parameters:
  ///   - command: The command name to search for (e.g. "codex")
  ///   - additionalPaths: Additional paths to search from configuration
  /// - Returns: The full path to the executable if found, nil otherwise
  public static func findCodexExecutable(
    command: String = "codex",
    additionalPaths: [String]?
  ) -> String? {
    let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return nil }

    let fileManager = FileManager.default
    let homeDir = NSHomeDirectory()

    let localCodexPath = "\(homeDir)/.codex/local/\(command)"
    if fileManager.isExecutableFile(atPath: localCodexPath) {
      return localCodexPath
    }

    if let nvmPath = CodexSDK.NvmPathDetector.detectNvmPath() {
      let nvmCodexPath = "\(nvmPath)/\(command)"
      if fileManager.isExecutableFile(atPath: nvmCodexPath) {
        return nvmCodexPath
      }
    }

    if command == "codex", let detected = CodexSDK.CodexBinaryDetector.detect() {
      return detected.path
    }

    return findExecutable(command: command, additionalPaths: additionalPaths)
  }

  /// Finds the full path to a CLI executable.
  /// - Parameters:
  ///   - command: The command name or executable path to search for
  ///   - additionalPaths: Additional paths to search from configuration
  /// - Returns: The full path to the executable if found, nil otherwise
  public static func findExecutable(
    command: String,
    additionalPaths: [String]?
  ) -> String? {
    let fileManager = FileManager.default
    let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return nil }

    if command.contains("/") {
      let path = (command as NSString).expandingTildeInPath
      return fileManager.isExecutableFile(atPath: path) ? path : nil
    }

    let homeDir = NSHomeDirectory()
    
    // Default search paths
    let defaultPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.claude/local",
      "\(homeDir)/.nvm/current/bin",
      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",
      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
    ]
    
    // Combine additional paths with default paths
    let allPaths = uniquePaths((additionalPaths ?? []) + defaultPaths)
    
    // Search for the command in all paths
    for path in allPaths {
      let fullPath = "\(path)/\(command)"
      if fileManager.isExecutableFile(atPath: fullPath) {
        return fullPath
      }
    }
    
    // Fallback: try using 'which' command
    let task = Process()
    task.launchPath = "/usr/bin/which"
    task.arguments = [command]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
      try task.run()
      task.waitUntilExit()
      
      if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      // Ignore errors from which command
    }
    
    return nil
  }

  private static func normalizedCommand(_ command: String, provider: LocalAgentProvider) -> String {
    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? provider.defaultCommand : trimmed
  }

  private static func normalizedOptionalArgument(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  private static func shellEscapeSingleQuoted(_ value: String) -> String? {
    if value.contains("\n") || value.contains("\r") {
      return nil
    }

    return shellEscapeSingleQuotedAllowingNewlines(value)
  }

  private static func shellEscapeSingleQuotedAllowingNewlines(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
  }

  private static func environmentExports(for environment: [String: String]) -> String {
    environment
      .filter { isValidEnvironmentName($0.key) }
      .sorted { $0.key < $1.key }
      .map { "export \($0.key)=\(shellEscapeSingleQuotedAllowingNewlines($0.value))" }
      .joined(separator: "\n")
  }

  private static func isValidEnvironmentName(_ name: String) -> Bool {
    guard let first = name.unicodeScalars.first else { return false }
    guard first == "_" || CharacterSet.letters.contains(first) else { return false }

    return name.unicodeScalars.allSatisfy { scalar in
      scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
    }
  }

  private static func uniquePaths(_ paths: [String]) -> [String] {
    var seen = Set<String>()
    return paths.filter { seen.insert($0).inserted }
  }

  private static func writeLaunchScript(content: String, prefix: String) throws -> URL {
    let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(prefix)_\(UUID().uuidString).command")

    do {
      try Data(content.utf8).write(to: scriptURL, options: .atomic)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: scriptURL.path
      )
      return scriptURL
    } catch {
      throw LocalAgentLaunchError.scriptWriteFailed(error.localizedDescription)
    }
  }
}
