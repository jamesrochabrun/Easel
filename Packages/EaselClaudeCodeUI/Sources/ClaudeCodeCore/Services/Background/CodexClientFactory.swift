//
//  CodexClientFactory.swift
//  ClaudeCodeUI
//
//  Builds CodexExecClient instances with Easel's binary-resolution rules:
//  user override → ~/.codex/local/codex → nvm path → CodexBinaryDetector.
//  Extracted from CodexChatRuntime so headless background runs configure
//  the CLI identically to the interactive chat.
//

import CodexSDK
import Foundation

// MARK: - CodexClientFactory

public enum CodexClientFactory {

  /// Shell-style tokenization for user-entered extra arguments; public
  /// passthrough so composing packages don't need CodexChatRuntime access.
  public static func parseArgumentString(_ value: String) -> [String] {
    CodexChatRuntime.parseArgumentString(value)
  }

  public static func makeClient(
    commandOverride: String?,
    environmentOverrides: [String: String],
    workingDirectory: String?
  ) -> CodexExecClient {
    CodexExecClient(
      configuration: makeConfiguration(
        commandOverride: commandOverride,
        environmentOverrides: environmentOverrides,
        workingDirectory: workingDirectory
      )
    )
  }

  static func makeConfiguration(
    commandOverride: String?,
    environmentOverrides: [String: String],
    workingDirectory: String?
  ) -> CodexExecConfiguration {
    var configuration = CodexExecConfiguration.withNvmSupport()
    configuration.enableDebugLogging = true
    configuration.useLoginShell = true
    configuration.workingDirectory = workingDirectory

    let homeDirectory = NSHomeDirectory()
    let trimmedCommandOverride = commandOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedCommandOverride.isEmpty {
      // User-specified command takes precedence over auto-detection.
      configuration.command = trimmedCommandOverride
    } else {
      let localCodexPath = "\(homeDirectory)/.codex/local/codex"
      if FileManager.default.isExecutableFile(atPath: localCodexPath) {
        configuration.command = localCodexPath
      } else {
        var commandFound = false
        if let nvmPath = NvmPathDetector.detectNvmPath() {
          let nvmCodexPath = "\(nvmPath)/codex"
          if FileManager.default.isExecutableFile(atPath: nvmCodexPath) {
            configuration.command = nvmCodexPath
            commandFound = true
          }
        }
        if !commandFound, let detected = CodexBinaryDetector.detect() {
          configuration.command = detected.path
        }
      }
    }

    configuration.additionalPaths.append(contentsOf: [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDirectory)/.bun/bin",
      "\(homeDirectory)/.deno/bin",
      "\(homeDirectory)/.cargo/bin",
      "\(homeDirectory)/.local/bin",
    ])

    // Apply user-provided environment overrides last so they win.
    for (key, value) in environmentOverrides {
      let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedKey.isEmpty else { continue }
      configuration.environment[trimmedKey] = value
    }

    return configuration
  }
}
