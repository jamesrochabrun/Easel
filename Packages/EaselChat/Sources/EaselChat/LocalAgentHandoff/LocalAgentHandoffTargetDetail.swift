//
//  LocalAgentHandoffTargetDetail.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffTargetDetail: View {
  let target: LocalAgentHandoffTarget
  let codebasePath: String?
  let selectedRepositoryPath: String?
  let createdProjectPath: String?
  let isCreatingProject: Bool
  let canCreateProject: Bool
  let onSelectRepository: () -> Void
  let onCreateProject: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    switch target {
    case .codebase:
      if let codebasePath {
        LocalAgentHandoffPathBadge(path: codebasePath, isSelected: true)
      } else {
        Label("No codebase attached", systemImage: "exclamationmark.triangle")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
      }

    case .selectedRepository:
      if let selectedRepositoryPath {
        HStack(spacing: 8) {
          LocalAgentHandoffPathBadge(path: selectedRepositoryPath, isSelected: true)

          Button("Change folder", systemImage: "folder", action: onSelectRepository)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help("Choose a different repository")
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Choose an existing repository for the agent to work in.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

          Button("Choose Folder…", systemImage: "folder", action: onSelectRepository)
            .buttonStyle(.bordered)
            .help("Choose an existing repository")
        }
      }

    case .newProject:
      if let createdProjectPath {
        LocalAgentHandoffPathBadge(path: createdProjectPath, isSelected: true)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Choose a root folder where the new project will be created.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

          Button(action: onCreateProject) {
            Label(
              isCreatingProject ? "Creating Project…" : "Choose Folder…",
              systemImage: isCreatingProject ? "hourglass" : "folder.badge.plus"
            )
          }
          .buttonStyle(.bordered)
          .disabled(!canCreateProject)
          .help("Choose a root folder for the new project")
        }
      }
    }
  }
}
