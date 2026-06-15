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

          Button("Change", systemImage: "folder.badge.plus", action: onSelectRepository)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help("Change repo")
        }
      } else {
        Button("Select Repo", systemImage: "folder.badge.plus", action: onSelectRepository)
          .buttonStyle(.bordered)
      }

    case .newProject:
      if let createdProjectPath {
        LocalAgentHandoffPathBadge(path: createdProjectPath, isSelected: true)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Select a root folder for your project.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

          Button(action: onCreateProject) {
            Label(isCreatingProject ? "Creating Project" : "Select Root Folder", systemImage: isCreatingProject ? "hourglass" : "folder.badge.plus")
          }
          .buttonStyle(.bordered)
          .disabled(!canCreateProject)
          .help("Select a root folder for your project")
        }
      }
    }
  }
}
