//
//  CanvasContentView.swift
//  Easel
//

import EaselChat
import EaselKit
import EaselServerManager
import EaselSlides
import EaselWebInspector
import SwiftUI

struct CanvasContentView: View {
  @Bindable var appState: AppState
  let initialPrompt: String
  let chatService: ChatService

  @State private var serverManager = ProjectServerManager()
  @State private var projectFileService = DefaultProjectFileService()
  @State private var sidebarViewModel: SidebarViewModel?
  @State private var designLibraryViewModel: DesignLibraryViewModel?
  @State private var resourcesViewModel = ProjectResourcesViewModel()
  @State private var designSystemSetupViewModel = DesignSystemSetupViewModel()
  @State private var designSystemBrowserViewModel = DesignSystemBrowserViewModel()
  @State private var localAgentHandoffViewModel = LocalAgentHandoffViewModel()
  @State private var contentMode: CanvasContentMode = .designs
  @State private var selectedCanvasSurface: CanvasSurface = .canvas
  @State private var panelLayoutState: CanvasPanelLayoutState = .allPanels
  @State private var isDesignSystemSetupPresented = false
  @State private var isDesignSystemBrowserPresented = false
  @State private var isLocalAgentHandoffPresented = false
  @State private var didHandleInitialPrompt = false
  @Environment(\.colorScheme) private var colorScheme

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 340
  private let windowControlLeadingReserve: CGFloat = 78

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, shouldShowSidebar {
        SidebarView(sidebarViewModel: sidebarVM, reservesWindowControls: true)
          .frame(width: sidebarWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading))

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)
      }

      if contentMode == .designs {
        designLibraryPanel
      } else {
        if panelLayoutState.showsChatPanel {
          VStack(spacing: 0) {
            HStack {
              leadingToolbarButtons

              Spacer()
            }
            .padding(.leading, chatToolbarLeadingPadding)
            .padding(.trailing, EaselDesignSystem.Spacing.large)
            .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme))

            Rectangle()
              .fill(EaselDesignSystem.Palette.border(for: colorScheme))
              .frame(height: 1)

            ChatPanelView(chatService: chatService)
              .frame(maxHeight: .infinity)
          }
          .frame(width: chatPanelWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading).combined(with: .opacity))

          Rectangle()
            .fill(EaselDesignSystem.Palette.border(for: colorScheme))
            .frame(width: 1)
        }

        canvasSurfacePanel
      }
    }
    .background(alignment: .topLeading) {
      // Hidden buttons host window-level keyboard shortcuts.
      ZStack {
        Button("Cycle panel layout", action: cyclePanelLayout)
          .keyboardShortcut("b", modifiers: .command)

        Button("Toggle designs grid", action: toggleDesignLibrary)
          .keyboardShortcut("1", modifiers: .command)
      }
      .buttonStyle(.plain)
      .frame(width: 1, height: 1)
      .opacity(0.001)
      .accessibilityHidden(true)
    }
    .animation(.easeInOut(duration: 0.25), value: panelLayoutState)
    .animation(.easeInOut(duration: 0.22), value: contentMode)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .ignoresSafeArea(.container, edges: .top)
    .tint(EaselDesignSystem.Palette.accent)
    .sheet(isPresented: $isLocalAgentHandoffPresented) {
      LocalAgentHandoffView(
        viewModel: localAgentHandoffViewModel,
        context: chatService.localAgentHandoffContext(),
        onClose: {
          isLocalAgentHandoffPresented = false
        }
      )
      .frame(minWidth: 760, idealWidth: 820, minHeight: 620, idealHeight: 680)
    }
    .task {
      if let appDelegate = NSApp.delegate as? AppDelegate {
        appDelegate.serverManager = serverManager
      }
      let vm = SidebarViewModel(sessionStorage: chatService.sessionStorage)
      let libraryVM = DesignLibraryViewModel(sessionStorage: chatService.sessionStorage)
      designLibraryViewModel = libraryVM
      vm.onSessionSelected = { session in
        enterWorkspace()
        Task {
          await chatService.initialize()
          await chatService.switchToSession(session)
          // Use running dev server URL if available, otherwise start one
          if let dir = chatService.currentWorkingDirectory {
            await startDevServer(for: dir)
          }
          await vm.loadSessions()
          await libraryVM.refresh()
        }
      }
      vm.onNewChatRequested = { workingDirectory in
        enterWorkspace()
        Task {
          await chatService.initialize()
          await chatService.startNewSession(workingDirectory: workingDirectory)
          if let dir = workingDirectory {
            await startDevServer(for: dir)
          }
          await vm.loadSessions()
          await libraryVM.refresh()
        }
      }
      vm.onProjectLaunchRequested = { launch in
        enterWorkspace()
        Task {
          await chatService.initialize()
          await chatService.startNewSession(workingDirectory: launch.project.workingDirectory)
          chatService.setCurrentProject(launch.project)
          await startDevServer(for: launch.project.workingDirectory)
          await vm.loadSessions()
          await libraryVM.refresh()
        }
      }
      vm.onOpenWorkspace = { workingDirectory, latestSession in
        guard chatService.currentWorkingDirectory != workingDirectory else { return }
        enterWorkspace()
        Task {
          await chatService.initialize()
          // Switching/starting a session sets the working directory, which
          // auto-resolves currentProject (nil for a design system folder).
          if let latestSession {
            await chatService.switchToSession(latestSession)
          } else if let workingDirectory {
            await chatService.startNewSession(workingDirectory: workingDirectory)
          }
          if let dir = workingDirectory {
            await startDevServer(for: dir)
          }
          await vm.loadSessions()
          await libraryVM.refresh()
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
          await libraryVM.refresh()
        }
      }
      vm.onProjectDeleted = {
        Task {
          await handleDeletedWorkspaceIfNeeded(using: vm, libraryViewModel: libraryVM)
        }
      }
      vm.onDesignSystemDeleted = {
        Task {
          await handleDeletedWorkspaceIfNeeded(using: vm, libraryViewModel: libraryVM)
        }
      }
      chatService.onSessionChanged = {
        Task {
          if let currentSessionId = chatService.currentSessionId {
            vm.completePendingNewSession(sessionId: currentSessionId)
          }
          await vm.loadSessions()
          await libraryVM.refresh()
        }
      }
      vm.isSidebarVisible = shouldShowSidebar
      sidebarViewModel = vm
      await libraryVM.refresh()

      if !didHandleInitialPrompt {
        didHandleInitialPrompt = true
        let trimmedPrompt = initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
          enterWorkspace()
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
          let shouldResumeContext = sidebarViewModel?.consumeHighFidelityContextResumeRequest() == true
          isDesignSystemSetupPresented = false
          if shouldResumeContext {
            Task { @MainActor in
              await Task.yield()
              sidebarViewModel?.requestHighFidelityContext()
            }
          }
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
            let shouldResumeContext = sidebarViewModel.consumeHighFidelityContextResumeRequest()
            isDesignSystemBrowserPresented = false
            if shouldResumeContext {
              Task { @MainActor in
                await Task.yield()
                sidebarViewModel.requestHighFidelityContext()
              }
            }
          }
        )
        .frame(minWidth: 1040, minHeight: 720)
      }
    }
  }

  private var shouldShowSidebar: Bool {
    panelLayoutState.showsSidebar
  }

  private var designLibraryPanel: some View {
    VStack(spacing: 0) {
      designLibraryToolbar

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      Group {
        if let designLibraryViewModel {
          DesignLibraryView(
            viewModel: designLibraryViewModel,
            showsHeader: false,
            onCreateDesign: showCreateControls,
            onOpenSelection: handleDesignLibrarySelection
          )
        } else {
          ProgressView("Loading designs...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var designLibraryToolbar: some View {
    HStack(spacing: 6) {
      leadingToolbarButtons

      Text("Designs")
        .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.leading, 8)

      if let itemCount = designLibraryViewModel?.visibleItems.count, itemCount > 0 {
        Text("\(itemCount)")
          .font(EaselDesignSystem.Typography.interface(size: 12, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(
            EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          )
      }

      if let viewModel = designLibraryViewModel, !viewModel.items.isEmpty {
        designLibraryFilterChips(viewModel)
      }

      Spacer()

      Button(action: refreshDesignLibrary) {
        Label("Refresh designs", systemImage: "arrow.clockwise")
          .labelStyle(.iconOnly)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .disabled(designLibraryViewModel?.isLoading == true)
      .help("Refresh designs")
    }
    .padding(.leading, designLibraryToolbarLeadingPadding)
    .padding(.trailing, 16)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  /// Kind filters shown beside the "Designs" title. Every kind starts selected;
  /// toggling one off hides that category from the grid below.
  @ViewBuilder
  private func designLibraryFilterChips(_ viewModel: DesignLibraryViewModel) -> some View {
    HStack(spacing: 6) {
      ForEach(DesignLibraryItemKind.allCases) { kind in
        DesignLibraryFilterChip(
          kind: kind,
          count: viewModel.itemCount(for: kind),
          isSelected: viewModel.selectedKinds.contains(kind),
          action: { viewModel.toggleKind(kind) }
        )
      }
    }
    .padding(.leading, 4)
  }

  private var leadingToolbarButtons: some View {
    HStack(spacing: 4) {
      Button(action: toggleSidebarPanel) {
        Label("Toggle sidebar", systemImage: "sidebar.left")
          .labelStyle(.iconOnly)
          .font(.system(size: 14, weight: .medium))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Toggle Sidebar")

      Button(action: toggleDesignLibrary) {
        Label(designLibraryButtonTitle, systemImage: designLibraryButtonSystemImage)
          .labelStyle(.iconOnly)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 28, height: 28)
          .background(
            contentMode == .designs ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          )
      }
      .buttonStyle(.plain)
      .foregroundStyle(designLibraryButtonForeground)
      .help("\(designLibraryButtonTitle) (⌘1)")
    }
  }

  private func enterWorkspace() {
    contentMode = .workspace
    sidebarViewModel?.isSidebarVisible = shouldShowSidebar
  }

  private func showDesignLibrary() {
    contentMode = .designs
    selectedCanvasSurface = .canvas
    sidebarViewModel?.selectedSessionId = nil
    sidebarViewModel?.isSidebarVisible = shouldShowSidebar

    Task {
      await designLibraryViewModel?.refresh()
      await sidebarViewModel?.loadSessions()
    }
  }

  @MainActor
  private func handleDeletedWorkspaceIfNeeded(
    using sidebarViewModel: SidebarViewModel,
    libraryViewModel: DesignLibraryViewModel
  ) async {
    await libraryViewModel.refresh()

    guard let deletedWorkingDirectory = chatService.currentWorkingDirectory,
          !sidebarViewModel.containsWorkspace(workingDirectory: deletedWorkingDirectory) else {
      return
    }

    await serverManager.stopServer(for: deletedWorkingDirectory)
    selectedCanvasSurface = .canvas

    if sidebarViewModel.openFirstWorkspace(excluding: deletedWorkingDirectory) {
      return
    }

    chatService.clearActiveWorkspace()
    showDesignLibrary()
  }

  private func toggleDesignLibrary() {
    if contentMode == .designs {
      enterWorkspace()
    } else {
      showDesignLibrary()
    }
  }

  private func refreshDesignLibrary() {
    Task {
      await designLibraryViewModel?.refresh()
    }
  }

  private func showCreateControls() {
    setPanelLayoutState(.allPanels)
  }

  private func handleDesignLibrarySelection(_ selection: DesignLibrarySelection) {
    enterWorkspace()

    switch selection {
    case .project(let project, _):
      openProjectFromLibrary(project, selection: selection)
    case .designSystem(let profile, _):
      openDesignSystemFromLibrary(profile, selection: selection)
    }
  }

  private func openProjectFromLibrary(
    _ project: EaselDesignProject,
    selection: DesignLibrarySelection
  ) {
    sidebarViewModel?.requestScrollToProjectHeader(workingDirectory: project.workingDirectory)

    Task {
      await chatService.initialize()

      if let latestSession = selection.latestSession {
        sidebarViewModel?.selectedSessionId = selection.latestSessionID
        await chatService.switchToSession(latestSession)
      } else {
        sidebarViewModel?.preparePendingNewSession(workingDirectory: project.workingDirectory)
        await chatService.startNewSession(workingDirectory: project.workingDirectory)
      }

      chatService.setCurrentProject(project)
      await startDevServer(for: project.workingDirectory)
      await sidebarViewModel?.loadSessions()
      sidebarViewModel?.requestScrollToProjectHeader(workingDirectory: project.workingDirectory)
      await designLibraryViewModel?.refresh()
    }
  }

  private func openDesignSystemFromLibrary(
    _ profile: EaselDesignSystemProfile,
    selection: DesignLibrarySelection
  ) {
    sidebarViewModel?.selectDesignSystem(.custom(profile))

    Task {
      await chatService.initialize()

      if let latestSession = selection.latestSession {
        sidebarViewModel?.selectedSessionId = selection.latestSessionID
        await chatService.switchToSession(latestSession)
      } else {
        sidebarViewModel?.preparePendingNewSession(workingDirectory: profile.workingDirectory)
        await chatService.startNewSession(workingDirectory: profile.workingDirectory)
      }

      await startDevServer(for: profile.workingDirectory)
      await sidebarViewModel?.loadSessions()
      await designLibraryViewModel?.refresh()
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

    if let sidebarViewModel,
       sidebarViewModel.consumeHighFidelityContextResumeRequest() {
      sidebarViewModel.selectDesignSystem(.custom(launch.profile))
      Task {
        await sidebarViewModel.loadSessions()
        await designLibraryViewModel?.refresh()
        await Task.yield()
        sidebarViewModel.requestHighFidelityContext()
      }
      return
    }

    enterWorkspace()
    selectedCanvasSurface = .canvas
    sidebarViewModel?.selectDesignSystem(.custom(launch.profile))

    Task {
      await chatService.initialize()
      sidebarViewModel?.preparePendingNewSession(workingDirectory: launch.profile.workingDirectory)
      await chatService.startNewSession(workingDirectory: launch.profile.workingDirectory)
      await startDevServer(for: launch.profile.workingDirectory)
      await sidebarViewModel?.loadSessions()
      await designLibraryViewModel?.refresh()
    }
  }

  private func cyclePanelLayout() {
    // In the designs grid there's no chat panel or canvas to cycle through, so
    // the four-state cycle would appear to do nothing on two of every four
    // presses. Collapse it to a simple sidebar show/hide toggle there.
    if contentMode == .designs {
      toggleSidebarPanel()
      return
    }

    var nextState = panelLayoutState
    nextState.advanceCommandShortcutCycle()
    setPanelLayoutState(nextState)
  }

  private func toggleSidebarPanel() {
    var nextState = panelLayoutState
    nextState.toggleSidebar()
    setPanelLayoutState(nextState)
  }

  private func toggleCanvasFullWidth() {
    var nextState = panelLayoutState
    nextState.toggleCanvasFullWidth()
    setPanelLayoutState(nextState)
  }

  private func setPanelLayoutState(_ state: CanvasPanelLayoutState) {
    panelLayoutState = state
    sidebarViewModel?.isSidebarVisible = shouldShowSidebar
  }

  private var canvasSurfacePanel: some View {
    VStack(spacing: 0) {
      canvasSurfaceTopBar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      Group {
        if let workspaceEmptyStateContent {
          CanvasWorkspaceEmptyState(
            content: workspaceEmptyStateContent,
            action: {
              handleWorkspaceEmptyStateAction(workspaceEmptyStateContent)
            }
          )
        } else {
          ZStack {
            Group {
              if isSlideDeckProject {
                SlideDeckPreviewView(
                  previewURLProvider: chatService,
                  projectPath: chatService.currentWorkingDirectory
                )
              } else {
                WebInspectorPreviewView(
                  previewURLProvider: chatService,
                  inspectorBridge: chatService,
                  projectPath: chatService.currentWorkingDirectory,
                  projectFileProvider: projectFileService
                )
              }
            }
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
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var workspaceEmptyStateContent: CanvasWorkspaceEmptyStateContent? {
    CanvasWorkspaceEmptyStateContent.resolve(
      currentWorkingDirectory: chatService.currentWorkingDirectory,
      designCount: designLibraryViewModel?.items.count
    )
  }

  private func handleWorkspaceEmptyStateAction(_ content: CanvasWorkspaceEmptyStateContent) {
    switch content {
    case .noDesigns:
      showCreateControls()
    case .noSelection:
      showDesignLibrary()
    }
  }

  private var canvasSurfaceTopBar: some View {
    HStack(spacing: 12) {
      Picker("Canvas surface", selection: $selectedCanvasSurface) {
        ForEach(CanvasSurface.allCases) { surface in
          Label(
            surface.displayName(isSlideDeckProject: isSlideDeckProject),
            systemImage: surface.systemImage(isSlideDeckProject: isSlideDeckProject)
          )
            .tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 250)

      Spacer()

      #if DEBUG
        if chatService.currentWorkingDirectory != nil {
          CanvasProjectTokenBadge(summary: chatService.currentWorkspaceUsageSummary)
        }
      #endif

      Button(action: showLocalAgentHandoff) {
        Label("Send Handoff", systemImage: "paperplane")
          .font(.system(size: 13, weight: .medium))
          .labelStyle(.iconOnly)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .disabled(chatService.localAgentHandoffContext() == nil)
      .help("Send Handoff")

      Button(action: toggleCanvasFullWidth) {
        Label(canvasWidthButtonTitle, systemImage: canvasWidthButtonSystemImage)
          .font(.system(size: 13, weight: .medium))
          .labelStyle(.iconOnly)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help(canvasWidthButtonTitle)

      if let currentWorkingDirectory = chatService.currentWorkingDirectory {
        Label(URL(fileURLWithPath: currentWorkingDirectory).lastPathComponent, systemImage: "folder")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(currentWorkingDirectory)
      }
    }
    .padding(.leading, canvasToolbarLeadingPadding)
    .padding(.trailing, 16)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
    .background(.regularMaterial)
  }

  private var chatToolbarLeadingPadding: CGFloat {
    panelLayoutState.showsSidebar ? EaselDesignSystem.Spacing.large : windowControlLeadingReserve
  }

  private var designLibraryToolbarLeadingPadding: CGFloat {
    shouldShowSidebar ? 16 : windowControlLeadingReserve
  }

  private var canvasToolbarLeadingPadding: CGFloat {
    panelLayoutState.showsChatPanel ? 16 : windowControlLeadingReserve
  }

  private var designLibraryButtonTitle: String {
    contentMode == .designs ? "Return to Workspace" : "Show Designs Grid"
  }

  private var designLibraryButtonSystemImage: String {
    contentMode == .designs ? "light.panel.fill" : "square.grid.2x2"
  }

  private var designLibraryButtonForeground: Color {
    contentMode == .designs
      ? EaselDesignSystem.Palette.accentForeground(for: colorScheme)
      : EaselDesignSystem.Palette.secondaryText(for: colorScheme)
  }

  private var canvasWidthButtonTitle: String {
    panelLayoutState.isCanvasFullWidth ? "Restore Side Panels" : "Expand Canvas Full Width"
  }

  private var canvasWidthButtonSystemImage: String {
    panelLayoutState.isCanvasFullWidth
      ? "arrow.down.right.and.arrow.up.left"
      : "arrow.up.left.and.arrow.down.right"
  }

  private func showLocalAgentHandoff() {
    localAgentHandoffViewModel.prepareForPresentation(context: chatService.localAgentHandoffContext())
    isLocalAgentHandoffPresented = true
  }

  private var isSlideDeckProject: Bool {
    chatService.currentProject?.kind == .slideDeck
  }
}

private enum CanvasSurface: String, CaseIterable, Identifiable {
  case canvas
  case resources

  var id: String { rawValue }

  func displayName(isSlideDeckProject: Bool) -> String {
    switch self {
    case .canvas:
      return isSlideDeckProject ? "Slides" : "Canvas"
    case .resources:
      return "Design Files"
    }
  }

  func systemImage(isSlideDeckProject: Bool) -> String {
    switch self {
    case .canvas:
      return isSlideDeckProject ? "rectangle.on.rectangle" : "rectangle.inset.filled"
    case .resources:
      return "photo.on.rectangle.angled"
    }
  }
}

private enum CanvasContentMode: Equatable {
  case designs
  case workspace
}
