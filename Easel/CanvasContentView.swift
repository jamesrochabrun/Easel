//
//  CanvasContentView.swift
//  Easel
//

import EaselChat
import EaselKit
import EaselPreview
import SwiftUI

struct CanvasContentView: View {
  @Bindable var appState: AppState
  @State private var chatService = ChatService()

  private let chatPanelWidth: CGFloat = 380

  var body: some View {
    HStack(spacing: 1) {
      // Left: Chat panel
      ChatPanelView(chatService: chatService, initialPrompt: appState.promptText)
        .frame(width: chatPanelWidth)
        .frame(maxHeight: .infinity)

      // Subtle divider
      Rectangle()
        .fill(.quaternary)
        .frame(width: 1)

      // Right: Web preview canvas
      WebPreviewPanel(
        previewURLProvider: chatService,
        inspectorBridge: chatService
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(GlassBackgroundView(material: .sidebar))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
