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
  let initialPrompt: String

  @State private var chatService = ChatService()

  private let chatPanelWidth: CGFloat = 380

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Back to Prompt", systemImage: "chevron.left", action: resetToCapsule)
          .buttonStyle(.borderless)

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.bar)

      Divider()

      HStack(spacing: 1) {
        ChatPanelView(chatService: chatService, initialPrompt: initialPrompt)
          .frame(width: chatPanelWidth)
          .frame(maxHeight: .infinity)

        Rectangle()
          .fill(.quaternary)
          .frame(width: 1)

        WebPreviewPanel(
          previewURLProvider: chatService,
          inspectorBridge: chatService
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .background(GlassBackgroundView(material: .sidebar))
  }

  private func resetToCapsule() {
    appState.resetToCapsule()
  }
}
