//
//  CodexDebugModelsCommandRunner.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

struct CodexDebugModelsCommandRunner: CodexDebugModelsCommandRunning {
  func debugModelsJSON(homeDirectory: String) async throws -> Data {
    let invocation = Self.codexInvocation(homeDirectory: homeDirectory)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: invocation.executablePath)
    process.arguments = invocation.arguments
    process.environment = Self.environment(homeDirectory: homeDirectory)

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let message = String(data: errorData, encoding: .utf8) ?? "codex debug models failed"
      throw CodexDebugModelsCommandError.nonZeroExit(message)
    }

    return output
  }

  private static func codexInvocation(homeDirectory: String) -> (executablePath: String, arguments: [String]) {
    let resolver = CodexCommandResolver(homeDirectory: homeDirectory)
    if let resolvedCommand = resolver.resolve() {
      return (resolvedCommand.path, ["debug", "models"])
    }

    return ("/usr/bin/env", ["codex", "debug", "models"])
  }

  private static func environment(homeDirectory: String) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["HOME"] = homeDirectory
    environment["CODEX_HOME"] = URL(fileURLWithPath: homeDirectory)
      .appendingPathComponent(".codex")
      .path

    let paths = CodexCommandResolver(homeDirectory: homeDirectory)
      .searchPathDirectories()

    if let currentPath = environment["PATH"], !currentPath.isEmpty {
      environment["PATH"] = (paths + [currentPath]).joined(separator: ":")
    } else {
      environment["PATH"] = paths.joined(separator: ":")
    }

    return environment
  }
}

private enum CodexDebugModelsCommandError: LocalizedError {
  case nonZeroExit(String)

  var errorDescription: String? {
    switch self {
    case .nonZeroExit(let message):
      return message
    }
  }
}
