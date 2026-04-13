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
    HStack(spacing: 8) {
      Button(action: onToggle) {
        HStack(spacing: 8) {
          Image(systemName: project.isExpanded ? "folder.fill" : "folder")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(width: 18)

          Text(project.displayName)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.primary)
            .lineLimit(1)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Spacer()

      if isHovering {
        Button(action: onNewChat) {
          Image(systemName: "plus")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
