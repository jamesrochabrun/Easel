//
//  ChatPanelView.swift
//  Easel
//

import ClaudeCodeCore
import ClaudeCodeSDK
import SwiftUI

struct ChatPanelView: View {
  let initialPrompt: String

  var body: some View {
    ClaudeCodeContainer(
      claudeCodeConfiguration: ClaudeCodeConfiguration(
        workingDirectory: NSHomeDirectory()
      ),
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
