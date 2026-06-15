//
//  LocalAgentHandoffResourcesSection.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffResourcesSection: View {
  let context: LocalAgentHandoffContext?

  var body: some View {
    LocalAgentHandoffSection(
      title: "Easel Resources",
      subtitle: "These design files are bundled and shared with the agent as read-only context."
    ) {
      if let context {
        LocalAgentHandoffPathBadge(path: context.easelProjectPath, isSelected: false)
      } else {
        Label("Select a project first", systemImage: "exclamationmark.triangle")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
      }
    }
  }
}
