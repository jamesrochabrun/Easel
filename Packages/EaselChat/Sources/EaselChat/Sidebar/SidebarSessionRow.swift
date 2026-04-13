//
//  SidebarSessionRow.swift
//  EaselChat
//

import ClaudeCodeCore
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
          .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
          .frame(width: 6, height: 6)

        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(sessionIdPrefix)
              .font(.system(.caption2, design: .monospaced))
              .foregroundColor(.secondary)

            Text("Claude")
              .font(.system(.caption2, design: .monospaced))
              .foregroundColor(.secondary)

            Spacer()

            Text(relativeTime)
              .font(.system(.caption2, design: .monospaced))
              .foregroundColor(.secondary)
          }

          Text(session.firstUserMessage.isEmpty ? "New Session" : session.firstUserMessage)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(isSelected ? .primary : .secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(isSelected ? Color.secondary.opacity(0.15) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
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
