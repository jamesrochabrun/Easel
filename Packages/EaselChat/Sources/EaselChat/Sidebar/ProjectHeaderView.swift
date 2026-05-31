//
//  ProjectHeaderView.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselKit
import SwiftUI

struct ProjectHeaderView: View {
  let project: ProjectGroup
  let onToggle: () -> Void
  let onNewChat: () -> Void

  @State private var isHovering = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Button(action: onToggle) {
        HStack(spacing: 8) {
          Image(systemName: project.kind?.systemImage ?? (project.isExpanded ? "folder.fill" : "folder"))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(project.project == nil ? EaselDesignSystem.Palette.secondaryText(for: colorScheme) : EaselDesignSystem.Palette.accent)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(project.displayName)
              .font(.callout.weight(.medium))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Text(project.subtitle)
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
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
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
        .help("New Codex session")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      isHovering
        ? EaselDesignSystem.Palette.hoverSurface(for: colorScheme)
        : EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
    )
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
