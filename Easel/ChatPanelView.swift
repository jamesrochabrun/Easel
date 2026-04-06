//
//  ChatPanelView.swift
//  Easel
//

import ClaudeCodeCore
import ClaudeCodeSDK
import SwiftUI

struct ChatPanelView: View {
  let initialPrompt: String

  private var config: ClaudeCodeConfiguration {
    var config = ClaudeCodeConfiguration.withNvmSupport()
    config.enableDebugLogging = true
    let homeDir = NSHomeDirectory()

    config.workingDirectory = homeDir

    // PRIORITY 1: Check for local Claude installation (usually the newest version)
    let localClaudePath = "\(homeDir)/.claude/local"
    if FileManager.default.fileExists(atPath: localClaudePath) {
      config.additionalPaths.insert(localClaudePath, at: 0)
    }
    // PRIORITY 2: Add essential system paths and common development tools
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

  var body: some View {
    ClaudeCodeContainer(
      claudeCodeConfiguration: config,
      uiConfiguration: UIConfiguration(
        appName: "Easel",
        showSettingsInNavBar: false,
        showRiskData: false,
        showTokenCount: true
      )
    )
    .background(GlassBackgroundView(material: .sidebar))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
