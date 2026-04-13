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
  @State private var sidebarViewModel: SidebarViewModel?

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 220

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, sidebarVM.isSidebarVisible {
        SidebarView(sidebarViewModel: sidebarVM)
          .frame(width: sidebarWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading))

        Rectangle()
          .fill(.quaternary)
          .frame(width: 1)
      }

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
    .animation(.easeInOut(duration: 0.25), value: sidebarViewModel?.isSidebarVisible)
    .background(GlassBackgroundView(material: .sidebar))
    .task {
      let vm = SidebarViewModel(sessionStorage: chatService.sessionStorage)
      vm.onSessionSelected = { session in
        Task {
          await chatService.switchToSession(session)
          await vm.loadSessions()
        }
      }
      vm.onNewChatRequested = { workingDirectory in
        Task {
          await chatService.startNewSession(workingDirectory: workingDirectory)
          await vm.loadSessions()
        }
      }
      vm.onDeleteSession = { session in
        Task {
          await chatService.deleteSession(session)
          await vm.loadSessions()
        }
      }
      chatService.onSessionChanged = {
        Task {
          await vm.loadSessions()
        }
      }
      sidebarViewModel = vm
    }
  }
}
