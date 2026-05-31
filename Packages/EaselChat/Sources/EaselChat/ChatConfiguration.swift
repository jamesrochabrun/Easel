//
//  ChatConfiguration.swift
//  EaselChat
//

import ClaudeCodeSDK
import Foundation

public enum ChatConfiguration {

  public static func makeDefault() -> ClaudeCodeConfiguration {
    var config = ClaudeCodeConfiguration.withNvmSupport()
    config.enableDebugLogging = true
    let homeDir = NSHomeDirectory()
    config.workingDirectory = nil

    let localClaudePath = "\(homeDir)/.claude/local"
    if FileManager.default.fileExists(atPath: localClaudePath) {
      config.additionalPaths.insert(localClaudePath, at: 0)
    }
    config.additionalPaths.append(contentsOf: [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.bun/bin",
      "\(homeDir)/.deno/bin",
      "\(homeDir)/.cargo/bin",
      "\(homeDir)/.local/bin",
    ])

    return config
  }
}
