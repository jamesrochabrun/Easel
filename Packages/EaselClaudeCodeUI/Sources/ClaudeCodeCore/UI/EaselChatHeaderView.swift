import SwiftUI

struct EaselChatHeaderView: View {
  let title: String
  let canContinueSession: Bool
  let canClearChat: Bool
  let showSettings: Bool
  let onToggleSidebar: () -> Void
  let onContinueSession: () -> Void
  let onClearChat: () -> Void
  let onShowSettings: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      Button("Toggle Sidebar", systemImage: "chevron.left", action: onToggleSidebar)
        .labelStyle(.iconOnly)
        .font(.system(size: 14, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
        .frame(width: 32, height: 32)

      Spacer()

      headerMenu
    }
    .overlay {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(EaselChatRuntimeStyle.appBackground(for: colorScheme))
  }

  private var headerMenu: some View {
    Menu {
      Button("Continue Session", systemImage: "ellipsis.bubble", action: onContinueSession)
        .disabled(!canContinueSession)

      Button("Clear Chat", systemImage: "trash", action: onClearChat)
        .disabled(!canClearChat)

      if showSettings {
        Divider()
        Button("Settings", systemImage: "gearshape", action: onShowSettings)
      }
    } label: {
      Text(avatarInitial)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(EaselChatRuntimeStyle.userText(for: colorScheme))
        .frame(width: 30, height: 30)
        .background(EaselChatRuntimeStyle.userBubble(for: colorScheme), in: Circle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .accessibilityLabel("Chat actions")
  }

  private var avatarInitial: String {
    title.first.map { String($0).uppercased() } ?? "E"
  }
}
