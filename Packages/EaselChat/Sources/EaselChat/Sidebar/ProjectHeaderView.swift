//
//  ProjectHeaderView.swift
//  EaselChat
//

import ClaudeCodeCore
import SwiftUI

struct ProjectHeaderView: View {
  let project: ProjectGroup
  let onToggle: () -> Void
  let onNewChat: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Button(action: onToggle) {
        HStack(spacing: 8) {
          Image(systemName: project.kind?.systemImage ?? (project.isExpanded ? "folder.fill" : "folder"))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(project.project == nil ? Color.secondary : Color.accentColor)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(project.displayName)
              .font(.callout.weight(.medium))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Text(project.subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Spacer()

      if isHovering {
        Button(action: onNewChat) {
          Image(systemName: "plus")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("New Codex session")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.primary.opacity(isHovering ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary, lineWidth: 1)
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
