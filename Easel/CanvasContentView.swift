//
//  CanvasContentView.swift
//  Easel
//

import EaselChat
import EaselKit
import EaselServerManager
import EaselWebInspector
import SwiftUI

struct CanvasContentView: View {
  @Bindable var appState: AppState
  let initialPrompt: String
  let chatService: ChatService

  @State private var serverManager = ProjectServerManager()
  @State private var projectFileService = DefaultProjectFileService()
  @State private var sidebarViewModel: SidebarViewModel?
  @State private var resourcesViewModel = ProjectResourcesViewModel()
  @State private var designSystemSetupViewModel = DesignSystemSetupViewModel()
  @State private var designSystemBrowserViewModel = DesignSystemBrowserViewModel()
  @State private var selectedCanvasSurface: CanvasSurface = .canvas
  @State private var isDesignSystemSetupPresented = false
  @State private var isDesignSystemBrowserPresented = false
  @State private var didHandleInitialPrompt = false
  @Environment(\.colorScheme) private var colorScheme

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 340

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, sidebarVM.isSidebarVisible {
        SidebarView(sidebarViewModel: sidebarVM)
          .frame(width: sidebarWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading))

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)
      }

      VStack(spacing: 0) {
        HStack {
          Button {
            sidebarViewModel?.toggleSidebar()
          } label: {
            Image(systemName: "sidebar.left")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .frame(width: 28, height: 28)
          }
          .buttonStyle(.plain)
          .keyboardShortcut("b", modifiers: .command)
          .help("Toggle Sidebar (⌘B)")

          Spacer()
        }
        .padding(.horizontal, EaselDesignSystem.Spacing.large)
        .padding(.vertical, EaselDesignSystem.Spacing.small)
        .frame(minHeight: EaselDesignSystem.Spacing.toolbarHeight)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme))

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(height: 1)

        ChatPanelView(chatService: chatService)
          .frame(maxHeight: .infinity)
      }
      .frame(width: chatPanelWidth)
      .frame(maxHeight: .infinity)

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(width: 1)

      canvasSurfacePanel
    }
    .animation(.easeInOut(duration: 0.25), value: sidebarViewModel?.isSidebarVisible)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
    .task {
      if let appDelegate = NSApp.delegate as? AppDelegate {
        appDelegate.serverManager = serverManager
      }
      let vm = SidebarViewModel(sessionStorage: chatService.sessionStorage)
      vm.onSessionSelected = { session in
        Task {
          await chatService.initialize()
          await chatService.switchToSession(session)
          // Use running dev server URL if available, otherwise start one
          if let dir = chatService.currentWorkingDirectory {
            await startDevServer(for: dir)
          }
          await vm.loadSessions()
        }
      }
      vm.onNewChatRequested = { workingDirectory in
        Task {
          await chatService.initialize()
          await chatService.startNewSession(workingDirectory: workingDirectory)
          if let dir = workingDirectory {
            await startDevServer(for: dir)
          }
          await vm.loadSessions()
        }
      }
      vm.onProjectLaunchRequested = { launch in
        Task {
          await chatService.initialize()
          await chatService.startNewSession(workingDirectory: launch.project.workingDirectory)
          await startDevServer(for: launch.project.workingDirectory)
          chatService.sendInitialPromptIfNeeded(launch.prompt)
          await vm.loadSessions()
        }
      }
      vm.onCreateDesignSystemRequested = {
        isDesignSystemSetupPresented = true
      }
      vm.onBrowseDesignSystemsRequested = {
        isDesignSystemBrowserPresented = true
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

      if !didHandleInitialPrompt {
        didHandleInitialPrompt = true
        let trimmedPrompt = initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
          await vm.createPrototypeProject(fromPrompt: trimmedPrompt)
        }
      }

      // Auto-start dev server for the default working directory
      if let dir = chatService.currentWorkingDirectory {
        await startDevServer(for: dir)
      }
    }
    .sheet(isPresented: $isDesignSystemSetupPresented) {
      DesignSystemSetupView(
        viewModel: designSystemSetupViewModel,
        onCancel: {
          isDesignSystemSetupPresented = false
        },
        onCreated: handleDesignSystemCreated
      )
      .frame(minWidth: 920, minHeight: 760)
    }
    .sheet(isPresented: $isDesignSystemBrowserPresented) {
      if let sidebarViewModel {
        DesignSystemBrowserView(
          sidebarViewModel: sidebarViewModel,
          viewModel: designSystemBrowserViewModel,
          onCreateDesignSystem: {
            isDesignSystemBrowserPresented = false
            isDesignSystemSetupPresented = true
          },
          onDone: {
            isDesignSystemBrowserPresented = false
          }
        )
        .frame(minWidth: 1040, minHeight: 720)
      }
    }
  }

  private func startDevServer(for workingDirectory: String) async {
    // If server already running, use its URL instantly
    if let existingURL = serverManager.serverURL(for: workingDirectory) {
      chatService.setPreviewURL(existingURL)
      return
    }
    // Start new dev server process
    do {
      let server = try await serverManager.startServer(for: workingDirectory)
      chatService.setPreviewURL(server.url)
    } catch {
      // Dev server failed — preview stays in "waiting" state
      // PreviewURLObserver can still detect URLs from chat messages as fallback
    }
  }

  private func handleDesignSystemCreated(_ launch: EaselDesignSystemLaunch) {
    isDesignSystemSetupPresented = false
    selectedCanvasSurface = .canvas
    sidebarViewModel?.selectDesignSystem(.custom(launch.profile))

    Task {
      await chatService.initialize()
      await chatService.startNewSession(workingDirectory: launch.profile.workingDirectory)
      await startDevServer(for: launch.profile.workingDirectory)
      chatService.sendInitialPromptIfNeeded(launch.prompt)
      await sidebarViewModel?.loadSessions()
    }
  }

  private var canvasSurfacePanel: some View {
    VStack(spacing: 0) {
      canvasSurfaceTopBar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      ZStack {
        WebInspectorPreviewView(
          previewURLProvider: chatService,
          inspectorBridge: chatService,
          projectPath: chatService.currentWorkingDirectory,
          projectFileProvider: projectFileService
        )
        .opacity(selectedCanvasSurface == .canvas ? 1 : 0)
        .allowsHitTesting(selectedCanvasSurface == .canvas)
        .accessibilityHidden(selectedCanvasSurface != .canvas)

        ProjectResourcesView(
          viewModel: resourcesViewModel,
          currentProjectPath: chatService.currentWorkingDirectory
        )
        .opacity(selectedCanvasSurface == .resources ? 1 : 0)
        .allowsHitTesting(selectedCanvasSurface == .resources)
        .accessibilityHidden(selectedCanvasSurface != .resources)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var canvasSurfaceTopBar: some View {
    HStack(spacing: 12) {
      Picker("Canvas surface", selection: $selectedCanvasSurface) {
        ForEach(CanvasSurface.allCases) { surface in
          Label(surface.displayName, systemImage: surface.systemImage)
            .tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 250)

      Spacer()

      if let currentWorkingDirectory = chatService.currentWorkingDirectory {
        Label(URL(fileURLWithPath: currentWorkingDirectory).lastPathComponent, systemImage: "folder")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(currentWorkingDirectory)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(minHeight: 52)
    .background(.regularMaterial)
  }
}

private enum CanvasSurface: String, CaseIterable, Identifiable {
  case canvas
  case resources

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .canvas:
      return "Canvas"
    case .resources:
      return "Resources"
    }
  }

  var systemImage: String {
    switch self {
    case .canvas:
      return "rectangle.inset.filled"
    case .resources:
      return "photo.on.rectangle.angled"
    }
  }
}
