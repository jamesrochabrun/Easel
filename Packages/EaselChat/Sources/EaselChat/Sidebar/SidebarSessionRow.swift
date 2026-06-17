//
//  SidebarSessionRow.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselKit
import SwiftUI

struct SidebarSessionRow: View {
  let session: StoredSession
  let isSelected: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        Circle()
          .fill(isSelected ? EaselDesignSystem.Palette.accent : EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          .frame(width: 6, height: 6)

        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(sessionIdPrefix)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

            Text("Codex")
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

            Spacer()

            #if DEBUG
              if session.usageSummary.hasUsage {
                Text(session.usageSummary.formattedTotalTokens)
                  .font(.system(.caption2, design: .monospaced))
                  .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                  .lineLimit(1)
                  .help("Exact provider-reported session API usage: \(session.usageSummary.formattedBreakdown)")
              }
            #endif

            Text(relativeTime)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }

          Text(session.firstUserMessage.isEmpty ? "New Session" : session.firstUserMessage)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(isSelected ? Color.primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(isSelected ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private var sessionIdPrefix: String {
    String(session.id.prefix(8))
  }

  private var relativeTime: String {
    let interval = Date().timeIntervalSince(session.lastAccessedAt)
    if interval < 60 {
      return "now"
    } else if interval < 3600 {
      let minutes = Int(interval / 60)
      return "\(minutes)m ago"
    } else if interval < 86400 {
      let hours = Int(interval / 3600)
      return "\(hours)h ago"
    } else {
      let days = Int(interval / 86400)
      return "\(days)d ago"
    }
  }
}
