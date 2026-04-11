//
//  CanvasContentView.swift
//  Easel
//

import EaselChat
import EaselKit
import EaselWebInspector
import SwiftUI

struct CanvasContentView: View {
  @Bindable var appState: AppState
  let initialPrompt: String

  @State private var chatService = ChatService()

  private let chatPanelWidth: CGFloat = 380

  var body: some View {
    HStack(spacing: 1) {
      ChatPanelView(chatService: chatService, initialPrompt: initialPrompt)
        .frame(width: chatPanelWidth)
        .frame(maxHeight: .infinity)

      Rectangle()
        .fill(.quaternary)
        .frame(width: 1)

      WebInspectorPreviewView(
        previewURLProvider: chatService,
        inspectorBridge: chatService
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(GlassBackgroundView(material: .sidebar))
  }
}
