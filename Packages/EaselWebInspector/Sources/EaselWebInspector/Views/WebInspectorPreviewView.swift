//
//  WebInspectorPreviewView.swift
//  EaselWebInspector
//
//  Main web preview container with full inspection capabilities.
//  Adapted from AgentHub's WebPreviewView — removes dev server management
//  and CLI session dependencies, keeping all inspection modes.
//

import AppKit
import Canvas
import EaselKit
import OSLog
import SwiftUI
import WebKit

private let inspectorLog = Logger(subsystem: "com.easel.webinspector", category: "WebInspectorPreviewView")

private final class WebPreviewConsoleMessageHandler: NSObject, WKScriptMessageHandler {
  var onMessage: ((String, String) -> Void)?

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard let body = message.body as? [String: Any],
          let level = body["level"] as? String,
          let payload = body["message"] as? String else {
      return
    }
    onMessage?(level, payload)
  }
}

public enum WebPreviewInspectBehavior: String, CaseIterable, Identifiable {
  case input
  case crop
  case context
  case edit

  public static func availableCases(advancedEditingEnabled: Bool) -> [WebPreviewInspectBehavior] {
    advancedEditingEnabled ? [.input, .crop, .edit] : [.input, .crop]
  }

  public var id: String { rawValue }

  public var icon: String {
    switch self {
    case .input: return "square.and.pencil"
    case .crop: return "crop"
    case .context: return "square.and.arrow.up"
    case .edit: return "slider.horizontal.3"
    }
  }

  public var helpText: String {
    switch self {
    case .input:
      return "Select an element, then type an instruction to queue it for the next message."
    case .crop:
      return "Drag to select a region, then describe the change to queue it for the next message."
    case .context:
      return "Queue selected elements in the preview to attach them to the next message."
    case .edit:
      return "Select an element and edit its backing source file directly."
    }
  }

  public var accessibilityLabel: String {
    switch self {
    case .input: return "Instruction mode"
    case .crop: return "Crop region mode"
    case .context: return "Queued context mode"
    case .edit: return "Source edit mode"
    }
  }

  public var modeName: String {
    switch self {
    case .input: return "inspect"
    case .crop: return "crop"
    case .context: return "context"
    case .edit: return "edit"
    }
  }

  public var canvasMode: InspectMode {
    switch self {
    case .input: return .input
    case .crop: return .crop
    case .context: return .context
    case .edit: return .input
    }
  }
}

// MARK: - WebInspectorPreviewView

public struct WebInspectorPreviewView: View {
  let previewURLProvider: PreviewURLProviding
  let inspectorBridge: InspectorBridgeProtocol
  let projectPath: String?
  let projectFileProvider: (any ProjectFileProviding)?
  let recentActivityProvider: (any RecentActivityProviding)?

  @State private var inspectState = ElementInspectState()
  @State private var inspectBehavior: WebPreviewInspectBehavior = .input
  @State private var localContextQueue = WebPreviewContextQueue()
  @State private var inspectorViewModel: WebPreviewInspectorViewModel?
  @State private var lastSelectedSelector: String?
  @State private var previewWebView: WKWebView?
  @State private var consoleMessageHandler = WebPreviewConsoleMessageHandler()
  @State private var scrollRestorationCoordinator = WebPreviewScrollRestorationCoordinator()
  @State private var manualReloadToken = UUID()
  @State private var autoReloadToken = UUID()
  @State private var tweaksState = TweaksState()
  @State private var tweaksAgentState: TweaksAgentState = .idle
  @State private var isTweaksPopoverPresented = false
  @State private var tweaksWriteCoordinator: TweaksDefaultsWriteCoordinator?
  @State private var queueSendFailureMessage: String?
  @State private var isLoading = false
  @State private var isShowingBuildPlaceholder = false
  @Environment(\.colorScheme) private var colorScheme

  private static let consoleMessageName = "easelConsole"

  private var normalizedProjectPath: String? {
    Self.normalizedProjectPath(projectPath)
  }

  private var isAdvancedEditingEnabled: Bool {
    projectFileProvider != nil && normalizedProjectPath != nil && inspectorViewModel != nil
  }

  private var showsInspectorRail: Bool {
    false
  }

  private var showsInlineDesignToolbar: Bool {
    isAdvancedEditingEnabled && inspectBehavior == .edit && (inspectorViewModel?.isPanelVisible ?? false)
  }

  private var updateState: WebPreviewUpdateState {
    WebPreviewUpdateState.resolve(
      hasPreview: previewURLProvider.previewURL != nil,
      isEditMode: isAdvancedEditingEnabled && inspectBehavior == .edit
    )
  }

  private var autoReloadTaskID: String {
    [
      normalizedProjectPath ?? "",
      previewURLProvider.previewURL?.absoluteString ?? "",
    ].joined(separator: "|")
  }

  private var activeSelectorToRestore: String? {
    guard !scrollRestorationCoordinator.suppressesSelectorRestore else { return nil }
    return lastSelectedSelector
  }

  public init(
    previewURLProvider: PreviewURLProviding,
    inspectorBridge: InspectorBridgeProtocol,
    projectPath: String? = nil,
    projectFileProvider: (any ProjectFileProviding)? = nil,
    recentActivityProvider: (any RecentActivityProviding)? = nil
  ) {
    self.previewURLProvider = previewURLProvider
    self.inspectorBridge = inspectorBridge
    self.projectPath = projectPath
    self.projectFileProvider = projectFileProvider
    self.recentActivityProvider = recentActivityProvider

    if let normalizedProjectPath = Self.normalizedProjectPath(projectPath),
       let projectFileProvider {
      _inspectorViewModel = State(initialValue: WebPreviewInspectorViewModel(
        projectPath: normalizedProjectPath,
        sourceResolver: WebPreviewSourceResolver(fileService: projectFileProvider),
        fileService: projectFileProvider,
        recentActivityProvider: recentActivityProvider
      ))
      _tweaksWriteCoordinator = State(initialValue: TweaksDefaultsWriteCoordinator(
        projectPath: normalizedProjectPath,
        fileService: projectFileProvider
      ))
    } else {
      _inspectorViewModel = State(initialValue: nil)
      _tweaksWriteCoordinator = State(initialValue: nil)
    }
  }

  public var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      content
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
    .task(id: normalizedProjectPath) {
      await configureInspectorViewModelForCurrentProject()
    }
    .task(id: autoReloadTaskID) {
      await observeProjectFileChangesForAutoReload()
    }
    .onChange(of: isTweaksPopoverPresented) { _, presented in
      if !presented {
        flushTweakWrites()
      }
    }
    .onDisappear {
      flushTweakWrites()
    }
    .onChange(of: inspectBehavior) { _, newBehavior in
      guard inspectState.isActive else { return }
      inspectState.activate(mode: newBehavior.canvasMode)
      if let inspectorViewModel {
        if newBehavior != .edit {
          flushPendingDesignEditsToQueue()
        }
        Task {
          await inspectorViewModel.flushPendingWriteIfNeeded()
          if newBehavior != .edit {
            await inspectorViewModel.closePanel()
          }
        }
      }
    }
    .onKeyPress(.escape) {
      if inspectState.isActive {
        if inspectState.selectedElement != nil {
          closeEditRail()
          return .handled
        }
        if inspectState.cropRect != nil {
          clearCropSelection()
          return .handled
        }
        deactivateInspector()
        return .handled
      }
      return .ignored
    }
    .onChange(of: inspectState.cropRect) { oldValue, newValue in
      // When the crop rect is dismissed (either by Esc in the text field,
      // the X button, or after a submit), Canvas only clears the Swift state.
      // We also need to tell the JS overlay to remove the crop rectangle visual.
      if oldValue != nil, newValue == nil, let webView = previewWebView {
        ElementInspectorBridge.clearCropSelection(in: webView)
      }
    }
    .onDisappear {
      deactivateInspector()
      if let inspectorViewModel {
        Task {
          await inspectorViewModel.flushPendingWriteIfNeeded()
        }
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 8) {
      centerIndicator

      Spacer()

      headerControls
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minHeight: 40)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  @ViewBuilder
  private var centerIndicator: some View {
    if let url = previewURLProvider.previewURL {
      HStack(spacing: 6) {
        Circle()
          .fill(EaselDesignSystem.Palette.success)
          .frame(width: 6, height: 6)
        Text(url.absoluteString)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
    } else {
      HStack(spacing: 6) {
        ProgressView().controlSize(.mini)
        Text("Waiting for preview...")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
    }
  }

  @ViewBuilder
  private var headerControls: some View {
    HStack(spacing: 12) {
      WebPreviewModeButton(
        title: "\(inspectState.isActive ? "Stop" : "Start") \(inspectBehavior.modeName) mode",
        systemImage: "cursorarrow.rays",
        isActive: inspectState.isActive,
        width: 24,
        height: 24,
        font: .system(size: 14, weight: .medium)
      ) {
        toggleInspector()
      }
      .help("\(inspectState.isActive ? "Stop" : "Start") \(inspectBehavior.modeName) mode")

      if inspectState.isActive {
        let availableModes = WebPreviewInspectBehavior.availableCases(advancedEditingEnabled: isAdvancedEditingEnabled)
        if availableModes.count > 1 {
          HStack(spacing: 6) {
            ForEach(availableModes) { behavior in
              WebPreviewModeButton(
                title: behavior.accessibilityLabel,
                systemImage: behavior.icon,
                isActive: inspectBehavior == behavior,
                width: 26,
                height: 20,
                font: .caption
              ) {
                inspectBehavior = behavior
              }
              .help(behavior.helpText)
            }
          }
          .padding(4)
          .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
          .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
          .overlay {
            RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
        }
      }

      if previewURLProvider.previewURL != nil, previewWebView != nil {
        Button {
          isTweaksPopoverPresented.toggle()
        } label: {
          Label("Tweaks", systemImage: "slider.horizontal.3")
            .font(.caption)
        }
        .webPreviewSecondaryButtonStyle()
        .controlSize(.small)
        .help("Tweak this design with live controls")
        .popover(isPresented: $isTweaksPopoverPresented, arrowEdge: .bottom) {
          tweaksPanel
        }

        Button {
          refreshPreview()
        } label: {
          Label("Reload", systemImage: "arrow.clockwise")
            .font(.caption)
        }
        .webPreviewSecondaryButtonStyle()
        .controlSize(.small)
        .help("Refresh preview")
      }
    }
    .overlay {
      HStack(spacing: 0) {
        Button("") { handleInspectModeShortcut() }
          .keyboardShortcut("i", modifiers: [.command, .shift])
        Button("") { refreshPreview() }
          .keyboardShortcut("r", modifiers: .command)
        if showsInspectorRail || showsInlineDesignToolbar {
          Button("") {
            if let inspectorViewModel, inspectorViewModel.pendingEditCount > 0 {
              applyPendingDesignEdits()
            } else {
              handleManualUpdate()
            }
          }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled((inspectorViewModel?.pendingEditCount ?? 0) == 0 && !updateState.isEnabled)
        }
      }
      .hidden()
      .frame(width: 0, height: 0)
    }
    .animation(.easeInOut(duration: 0.2), value: inspectBehavior)
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    HStack(spacing: 0) {
      previewContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      if showsInspectorRail, let inspectorViewModel {
        WebPreviewInspectorRail(
          viewModel: inspectorViewModel,
          updateState: updateState,
          onUpdate: handleManualUpdate,
          onApplyPendingEdits: applyPendingDesignEdits,
          onClose: closeEditRail
        )
        .frame(width: 360)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: showsInspectorRail)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !localContextQueue.isEmpty {
        bottomBarContent
      }
    }
    .animation(.easeInOut(duration: 0.2), value: localContextQueue.isEmpty)
  }

  @ViewBuilder
  private var previewContent: some View {
    if let url = previewURLProvider.previewURL {
      inspectablePreview(
        url: url,
        isFileURL: false,
        reloadToken: scrollRestorationCoordinator.effectiveReloadToken
      )
      .overlay {
        if isShowingBuildPlaceholder {
          buildPlaceholderView
        }
      }
    } else {
      placeholderView
    }
  }

  /// Covers the embedded preview while the dev server is serving a directory listing —
  /// the transient, unstyled page shown when the agent has deleted `index.html` and is
  /// still generating its replacement. Keeps the surface on-brand instead of exposing the
  /// raw autoindex.
  private var buildPlaceholderView: some View {
    ZStack {
      EaselDesignSystem.Palette.surface(for: colorScheme)

      VStack(spacing: 14) {
        ProgressView()
          .controlSize(.large)

        Text("Building your project…")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        Text("Your preview updates the moment it's ready.")
          .font(.system(size: 13))
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Building your project. Your preview updates the moment it's ready.")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .transition(.opacity)
  }

  private var placeholderView: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "globe")
        .font(.system(size: 36, weight: .thin))
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

      Text("Preview")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      Text("Web preview will appear here")
        .font(.system(size: 13))
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var bottomBarContent: some View {
    WebPreviewQueuedContextView(
      queuedItems: localContextQueue.items,
      isQueueing: inspectState.isActive && inspectBehavior != .edit,
      isSendShortcutEnabled: !inspectState.isInputShowing && !inspectState.isCropInputShowing,
      failureMessage: queueSendFailureMessage,
      onRemoveItem: { id in
        localContextQueue.remove(id: id)
      },
      onSendAll: sendQueuedContext,
      onClearAll: {
        localContextQueue.clear()
        queueSendFailureMessage = nil
      }
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  // MARK: - Inspectable Preview

  private func inspectablePreview(
    url: URL,
    isFileURL: Bool,
    reloadToken: UUID?
  ) -> some View {
    Group {
      if isAdvancedEditingEnabled && inspectBehavior == .edit, let inspectorViewModel {
        InspectableWebView(
          url: url,
          isFileURL: isFileURL,
          inspectorDataLevel: .full,
          onLoadingChange: handlePreviewLoadingChange,
          onURLChange: { _ in installConsoleHookIfReady() },
          onError: { _ in },
          reloadToken: reloadToken,
          onElementSelected: { element in
            handleElementSelected(element)
          },
          onSelectedElementDataChange: { element in
            handleSelectedElementDataChange(element)
          },
          onSelectedElementViewportRectChange: { rect in
            inspectState.updateSelectedElementViewportRect(rect)
          },
          isInspectModeActive: $inspectState.isActive,
          selectedElementId: inspectState.selectedElement?.id,
          selectorToRestore: activeSelectorToRestore,
          onWebViewReady: handleWebViewReady,
          onTweakPropsChange: { tweaksState.updateSchema($0) }
        )
        .overlay(alignment: .top) {
          if inspectState.isActive {
            VStack(spacing: 8) {
              editModeBanner(viewModel: inspectorViewModel)

              if showsInlineDesignToolbar,
                 let element = inspectorViewModel.selectedElement,
                 let toolbarValues = inspectorViewModel.toolbarValues {
                DesignToolbarContent(
                  values: toolbarValues,
                  element: element,
                  isTextContentEditable: inspectorViewModel.canEditContent,
                  onEdit: inspectorViewModel.apply
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .inspectOverlayCursor(label: "inlineDesignToolbar") { hovering in
                  handleInspectOverlayHover(hovering)
                }
              }

              if inspectBehavior == .edit, inspectorViewModel.pendingEditCount > 0 {
                WebPreviewPendingEditsBar(
                  count: inspectorViewModel.pendingEditCount,
                  tierLabel: inspectorViewModel.persistenceTierLabel,
                  onApply: applyPendingDesignEdits
                )
                .inspectOverlayCursor(label: "pendingEditsBar") { hovering in
                  handleInspectOverlayHover(hovering)
                }
              }

              if inspectBehavior == .edit, let offer = inspectorViewModel.tokenPromotionOffer {
                WebPreviewTokenPromotionBar(
                  offer: offer,
                  onPromote: {
                    Task {
                      await inspectorViewModel.promoteTokenDetachment()
                      refreshPreview()
                    }
                  },
                  onDismiss: { inspectorViewModel.dismissTokenPromotionOffer() }
                )
                .inspectOverlayCursor(label: "tokenPromotionBar") { hovering in
                  handleInspectOverlayHover(hovering)
                }
              }
            }
          }
        }
      } else {
        InspectableWebView(
          url: url,
          isFileURL: isFileURL,
          inspectorDataLevel: .regular,
          onLoadingChange: handlePreviewLoadingChange,
          onURLChange: { _ in installConsoleHookIfReady() },
          onError: { _ in },
          reloadToken: reloadToken,
          onElementSelected: { element in
            handleElementSelected(element)
          },
          onSelectedElementDataChange: { element in
            handleSelectedElementDataChange(element)
          },
          onSelectedElementViewportRectChange: { rect in
            inspectState.updateSelectedElementViewportRect(rect)
          },
          onCropRectSelected: { rect, elements in
            inspectState.selectCropRect(rect, elements: elements)
          },
          onCropRectViewportChange: { rect in
            inspectState.updateCropRect(rect)
          },
          isInspectModeActive: $inspectState.isActive,
          inspectMode: inspectBehavior.canvasMode,
          selectedElementId: inspectState.selectedElement?.id,
          selectorToRestore: activeSelectorToRestore,
          onWebViewReady: handleWebViewReady,
          onTweakPropsChange: { tweaksState.updateSchema($0) }
        )
        .webInspectorOverlay(
          state: inspectState,
          inputPlacement: .selectionAnchored,
          onSubmit: { element, instruction in
            handleInspectUpdateSubmit(element: element, instruction: instruction)
          },
          onSubmitAndSend: { element, instruction in
            handleInspectUpdateSubmitAndSend(element: element, instruction: instruction)
          },
          onContextSelection: { element in
            handleContextSelection(element: element)
          },
          onCropSubmit: { rect, elements, instruction in
            handleCropSubmit(rect: rect, elements: elements, instruction: instruction)
          },
          onCropSubmitAndSend: { rect, elements, instruction in
            handleCropSubmitAndSend(rect: rect, elements: elements, instruction: instruction)
          },
          onOverlayHoverChange: { hovering in
            handleInspectOverlayHover(hovering)
          },
          deactivateOnSubmit: false
        )
      }
    }
  }

  // MARK: - Actions

  private func toggleInspector() {
    if inspectState.isActive {
      deactivateInspector()
    } else {
      inspectState.activate(mode: inspectBehavior.canvasMode)
    }
  }

  private func handleInspectModeShortcut() {
    let availableModes = WebPreviewInspectBehavior.availableCases(advancedEditingEnabled: isAdvancedEditingEnabled)
    guard let firstMode = availableModes.first else { return }

    guard inspectState.isActive else {
      inspectBehavior = firstMode
      inspectState.activate(mode: firstMode.canvasMode)
      return
    }

    guard let currentIndex = availableModes.firstIndex(of: inspectBehavior) else {
      inspectBehavior = firstMode
      return
    }

    let nextIndex = availableModes.index(after: currentIndex)
    guard nextIndex < availableModes.endIndex else {
      deactivateInspector()
      return
    }

    inspectBehavior = availableModes[nextIndex]
  }

  private func deactivateInspector() {
    flushPendingDesignEditsToQueue()
    inspectState.deactivate()
    if let inspectorViewModel {
      Task {
        await inspectorViewModel.closePanel()
      }
    }
  }

  private func refreshPreview() {
    if let previewWebView, let previewURL = previewURLProvider.previewURL {
      reloadPreviewWebViewIgnoringCache(previewWebView, fallbackURL: previewURL, reason: "manual")
      return
    }

    manualReloadToken = UUID()
    scrollRestorationCoordinator.reset(to: manualReloadToken)
  }

  private func autoReloadPreview() {
    guard let previewURL = previewURLProvider.previewURL else { return }

    if let previewWebView {
      reloadPreviewWebViewIgnoringCache(previewWebView, fallbackURL: previewURL, reason: "auto")
      return
    }

    autoReloadToken = UUID()
    scrollRestorationCoordinator.reset(to: autoReloadToken)
  }

  private func reloadPreviewWebViewIgnoringCache(
    _ webView: WKWebView,
    fallbackURL: URL,
    reason: String
  ) {
    let request = WebPreviewReloadRequestFactory.request(
      currentURL: webView.url,
      fallbackURL: fallbackURL
    )
    inspectorLog.info("Hard reloading embedded preview (\(reason)): \(request.url?.absoluteString ?? fallbackURL.absoluteString)")

    Task { @MainActor in
      await clearPreviewCache(in: webView.configuration.websiteDataStore)
      guard !Task.isCancelled else { return }
      webView.load(request)
    }
  }

  private func clearPreviewCache(in dataStore: WKWebsiteDataStore) async {
    await withCheckedContinuation { continuation in
      dataStore.removeData(
        ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
        modifiedSince: .distantPast
      ) {
        continuation.resume()
      }
    }
  }

  private func handleManualUpdate() {
    guard let inspectorViewModel else { return }
    Task {
      await updateState.performUpdate(
        flushPendingWrites: {
          await inspectorViewModel.flushPendingWriteIfNeeded()
        },
        reload: refreshPreview
      )
    }
  }

  private func closeEditRail() {
    flushPendingDesignEditsToQueue()
    inspectState.dismissInput()
    lastSelectedSelector = nil
    if let inspectorViewModel {
      Task {
        await inspectorViewModel.closePanel()
      }
    }
  }

  private func clearCropSelection() {
    inspectState.dismissCropRect()
    if let previewWebView {
      ElementInspectorBridge.clearCropSelection(in: previewWebView)
    }
  }

  private func handleElementSelected(_ element: ElementInspectorData) {
    inspectState.selectElement(element)
    lastSelectedSelector = element.cssSelector

    if inspectBehavior == .context {
      localContextQueue.append(element)
      inspectState.dismissInput()
      return
    }

    if inspectBehavior == .edit, let inspectorViewModel {
      flushPendingDesignEditsToQueue()
      Task {
        await inspectorViewModel.inspect(
          element: element,
          previewFilePath: servedPreviewFilePath,
          stylesheetContext: stylesheetPreviewContext
        )
      }
    }
  }

  /// The on-disk path of the previewed document, when the preview is served
  /// straight from a local file rather than a dev server.
  private var servedPreviewFilePath: String? {
    guard let url = previewURLProvider.previewURL, url.isFileURL else { return nil }
    return url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  /// How the current preview serves its stylesheets, so Edit Mode can prove
  /// direct CSS write targets. File URLs resolve rules from disk; http(s)
  /// previews use in-page CSSOM provenance.
  private var stylesheetPreviewContext: WebPreviewStylesheetPreviewContext? {
    guard let projectPath = normalizedProjectPath,
          let url = previewURLProvider.previewURL else {
      return nil
    }
    if url.isFileURL {
      return .directFile(
        servedFilePath: url.standardizedFileURL.resolvingSymlinksInPath().path,
        projectPath: projectPath
      )
    }
    return .devServer(baseURL: url, projectPath: projectPath)
  }

  /// Describes the running preview so agent prompts can reference it.
  private var previewContextDescription: String? {
    guard let url = previewURLProvider.previewURL else { return nil }
    if url.isFileURL {
      return "static file preview of \(url.lastPathComponent)"
    }
    return "dev server at \(url.absoluteString)"
  }

  // MARK: - Tweaks

  private var tweaksPanel: some View {
    TweaksPanelView(
      state: tweaksState,
      agentState: tweaksAgentState,
      onSubmitDescription: { instruction in
        runTweakAgent(
          TweaksPromptBuilder.customPrompt(fileName: tweaksFileName, instruction: instruction)
        )
      },
      onIdeas: {
        runTweakAgent(
          TweaksPromptBuilder.ideasPrompt(fileName: tweaksFileName)
        )
      },
      onValueChange: handleTweakValueChange
    )
    .frame(width: 320)
  }

  /// Name of the previewed document for tweaks prompts.
  private var tweaksFileName: String {
    guard let url = previewURLProvider.previewURL else { return "index.html" }
    let name = url.lastPathComponent
    guard !name.isEmpty, name != "/" else { return "index.html" }
    return name
  }

  private func runTweakAgent(_ prompt: String) {
    guard tweaksAgentState != .working,
          let projectPath = normalizedProjectPath,
          let previewURL = previewURLProvider.previewURL,
          let filePath = TweaksDefaultsWriteCoordinator.resolveFilePath(
            previewURL: previewURL,
            projectPath: projectPath
          ) else {
      tweaksAgentState = .failed("The preview file could not be resolved.")
      return
    }

    tweaksAgentState = .working
    Task {
      do {
        let result = try await inspectorBridge.runTweakAgent(
          prompt: prompt,
          targetFileURL: URL(fileURLWithPath: filePath)
        )
        switch result {
        case .applied:
          tweaksAgentState = .idle
        case .noChanges:
          tweaksAgentState = .failed("The agent finished without changing the design file.")
        case .conflict:
          tweaksAgentState = .conflict
        }
      } catch {
        tweaksAgentState = .failed(error.localizedDescription)
      }
    }
  }

  /// Live-applies a tweak into the running page and schedules a debounced
  /// write of the new default back into the previewed file.
  private func handleTweakValueChange(_ prop: TweakProp, _ value: TweakPropValue) {
    tweaksState.updateValue(name: prop.name, value)
    if let previewWebView {
      TweaksBridge.setProp(name: prop.name, value: value, in: previewWebView)
    }

    guard let tweaksWriteCoordinator,
          let projectPath = normalizedProjectPath,
          let url = previewURLProvider.previewURL,
          let filePath = TweaksDefaultsWriteCoordinator.resolveFilePath(
            previewURL: url,
            projectPath: projectPath
          ) else {
      return
    }
    let liveSchemaNames = tweaksState.props.map(\.name)
    Task {
      await tweaksWriteCoordinator.scheduleWrite(
        propName: prop.name,
        value: value,
        filePath: filePath,
        liveSchemaNames: liveSchemaNames
      )
    }
  }

  private func flushTweakWrites() {
    guard let tweaksWriteCoordinator else { return }
    Task {
      await tweaksWriteCoordinator.flush()
    }
  }

  /// Sends the pending design-edit batch to the session's agent immediately.
  /// Falls back to the context queue when sending fails so nothing is lost.
  private func applyPendingDesignEdits() {
    guard let inspectorViewModel else { return }
    queueSendFailureMessage = nil
    guard let handoff = inspectorViewModel.takePendingDesignEditHandoff(
      previewContext: previewContextDescription
    ) else { return }

    var queue = WebPreviewContextQueue()
    queue.append(handoff.element, instruction: handoff.instruction)

    guard sendWebPreviewQueue(queue) else {
      localContextQueue.append(handoff.element, instruction: handoff.instruction)
      return
    }
  }

  /// Moves the pending design-edit batch into the local context queue, where
  /// it is sent with the next message and remains removable as a chip.
  private func flushPendingDesignEditsToQueue() {
    guard let inspectorViewModel,
          let handoff = inspectorViewModel.takePendingDesignEditHandoff(
            previewContext: previewContextDescription
          ) else { return }
    queueSendFailureMessage = nil
    localContextQueue.append(handoff.element, instruction: handoff.instruction)
  }

  private func handleSelectedElementDataChange(_ element: ElementInspectorData) {
    inspectState.refreshSelectedElement(element)
    lastSelectedSelector = element.cssSelector

    guard inspectBehavior == .edit, let inspectorViewModel else { return }
    inspectorViewModel.refreshFromLiveElement(element)
  }

  private func handleInspectUpdateSubmit(element: ElementInspectorData, instruction: String) {
    queueSendFailureMessage = nil
    localContextQueue.append(element, instruction: instruction)
    inspectState.dismissInput()
  }

  private func handleInspectUpdateSubmitAndSend(element: ElementInspectorData, instruction: String) {
    queueSendFailureMessage = nil
    var queue = WebPreviewContextQueue()
    queue.append(element, instruction: instruction)
    _ = sendWebPreviewQueue(queue)
    inspectState.dismissInput()
  }

  private func handleContextSelection(element: ElementInspectorData) {
    localContextQueue.append(element)
    inspectState.dismissInput()
  }

  private func handleCropSubmit(rect: CGRect, elements: [ElementInspectorData], instruction: String) {
    inspectorLog.debug("handleCropSubmit called rect=\(rect.debugDescription) elements=\(elements.count)")

    Task { @MainActor in
      let screenshotPath = await captureCropScreenshotPath(for: rect)
      clearCropSelection()

      inspectorLog.debug("Appending crop to queue, screenshotPath=\(screenshotPath ?? "nil")")
      localContextQueue.appendCrop(
        cropRect: rect,
        elements: elements,
        instruction: instruction,
        screenshotPath: screenshotPath
      )
    }
  }

  private func handleCropSubmitAndSend(rect: CGRect, elements: [ElementInspectorData], instruction: String) {
    Task { @MainActor in
      queueSendFailureMessage = nil
      let screenshotPath = await captureCropScreenshotPath(for: rect)
      clearCropSelection()

      var queue = WebPreviewContextQueue()
      queue.appendCrop(
        cropRect: rect,
        elements: elements,
        instruction: instruction,
        screenshotPath: screenshotPath
      )

      _ = sendWebPreviewQueue(queue)
    }
  }

  @MainActor
  private func captureCropScreenshotPath(for rect: CGRect) async -> String? {
    guard let webView = previewWebView else {
      inspectorLog.error("previewWebView is nil at crop submit time")
      return nil
    }

    inspectorLog.debug("Capturing screenshot via ElementSnapshotCapture, webView bounds=\(webView.bounds.debugDescription)")
    guard let image = try? await ElementSnapshotCapture.captureSnapshot(of: rect, in: webView) else {
      inspectorLog.error("ElementSnapshotCapture.captureSnapshot returned nil or threw")
      return nil
    }

    inspectorLog.debug("Snapshot succeeded, size=\(NSStringFromSize(image.size))")
    return saveCropScreenshot(image)
  }

  private func saveCropScreenshot(_ image: NSImage) -> String? {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      inspectorLog.error("Failed to encode NSImage to PNG")
      return nil
    }

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("Easel/crop-screenshots", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let filename = "crop-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).png"
    let fileURL = dir.appendingPathComponent(filename)
    do {
      try pngData.write(to: fileURL)
      inspectorLog.debug("Saved crop PNG to \(fileURL.path)")
      return fileURL.path
    } catch {
      inspectorLog.error("Failed to write PNG: \(error.localizedDescription)")
      return nil
    }
  }

  private func sendQueuedContext() {
    guard sendWebPreviewQueue(localContextQueue) else { return }
    localContextQueue.clear()
    queueSendFailureMessage = nil
  }

  @discardableResult
  private func sendWebPreviewQueue(_ queue: WebPreviewContextQueue) -> Bool {
    guard let prompt = queue.composedContextPrompt() else {
      return false
    }

    inspectorBridge.sendInspectorPrompt(
      terminalPrompt(for: prompt, screenshotPaths: queue.screenshotPaths())
    )
    return true
  }

  private func terminalPrompt(for prompt: String, screenshotPaths: [String]) -> String {
    guard !screenshotPaths.isEmpty else { return prompt }

    let pathsPrefix = screenshotPaths
      .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
      .joined(separator: " ")
    return "\(pathsPrefix) \(prompt)"
  }

  private func handlePreviewLoadingChange(_ loading: Bool) {
    isLoading = loading
    handleOverlayReloadingState(loading)

    // The page re-declares its tweak schema via dc_set_props on every load.
    if loading {
      tweaksState.clear()
    }

    guard !loading else { return }
    updateBuildPlaceholderVisibility()
    installConsoleHookIfReady()
  }

  /// After a load settles, show the branded placeholder when the dev server returned a
  /// directory listing (no index document yet) and hide it once a real page loads. Left
  /// untouched while a load is in flight so the listing never flashes during a reload.
  private func updateBuildPlaceholderVisibility() {
    let showsListing = WebPreviewDirectoryListingDetector.isDirectoryListing(title: previewWebView?.title)
    guard isShowingBuildPlaceholder != showsListing else { return }
    withAnimation(.easeInOut(duration: 0.2)) {
      isShowingBuildPlaceholder = showsListing
    }
  }

  private func handleOverlayReloadingState(_ loading: Bool) {
    guard inspectState.selectedElement != nil else { return }
    if loading {
      inspectState.isReloading = true
    } else {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        inspectState.isReloading = false
      }
    }
  }

  private func handleInspectOverlayHover(_ hovering: Bool) {
    let shouldRestoreCrosshair = inspectState.isActive
    let cursor = hovering ? "default" : (shouldRestoreCrosshair ? "crosshair" : "")
    let script = cursor.isEmpty
      ? "document.body.style.cursor = ''"
      : "document.body.style.cursor = '\(cursor)'"
    previewWebView?.evaluateJavaScript(script) { _, _ in }
    if hovering {
      NSCursor.arrow.set()
    }
  }

  private func editModeBanner(viewModel: WebPreviewInspectorViewModel) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "slider.horizontal.3")
        .font(.system(size: 12))
        .foregroundStyle(.white)

      Text(viewModel.isResolving ? "Edit Mode - mapping source" : "Edit Mode - click any element to edit")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)

      Spacer()

      Button {
        inspectState.deactivate()
        Task {
          await viewModel.closePanel()
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.8))
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Exit inspect mode (Esc)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(EaselDesignSystem.Palette.accent.opacity(0.9))
    .contentShape(Rectangle())
    .inspectOverlayCursor(label: "editModeBanner") { hovering in
      handleInspectOverlayHover(hovering)
    }
    .padding(12)
  }

  private func handleWebViewReady(_ webView: WKWebView) {
    Task { @MainActor in
      previewWebView = webView
    }

    attachInspectorViewModel(to: webView)

    let controller = webView.configuration.userContentController
    controller.removeScriptMessageHandler(forName: Self.consoleMessageName)
    controller.add(WeakScriptMessageHandler(consoleMessageHandler), name: Self.consoleMessageName)
    installConsoleHook(in: webView)
  }

  /// Binds the current inspector view model to the live preview web view.
  /// Called both when the web view becomes ready and when the view model is
  /// recreated for a project change — whichever happens last completes the
  /// wiring, so Edit Mode tier proving always has a web view to query.
  private func attachInspectorViewModel(to webView: WKWebView) {
    guard isAdvancedEditingEnabled, let inspectorViewModel else { return }
    inspectorViewModel.registerWebView(webView)
    consoleMessageHandler.onMessage = { [weak inspectorViewModel] level, message in
      Task { @MainActor in
        inspectorViewModel?.appendConsoleEntry(level: level, message: message)
      }
    }
  }

  private func installConsoleHookIfReady() {
    guard let previewWebView else { return }
    installConsoleHook(in: previewWebView)
  }

  private func installConsoleHook(in webView: WKWebView) {
    guard isAdvancedEditingEnabled else { return }
    webView.evaluateJavaScript(Self.consoleHookScript) { _, _ in }
  }

  private func observeProjectFileChangesForAutoReload() async {
    guard previewURLProvider.previewURL != nil,
          let normalizedProjectPath else {
      return
    }

    let observer = WebPreviewProjectFileChangeObserver(projectPath: normalizedProjectPath)
    _ = await observer.hasChangedSinceLastSnapshot()

    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(600))
      guard !Task.isCancelled else { return }

      if await observer.hasChangedSinceLastSnapshot() {
        // Tweaks persistence writes the previewed file itself; the live page
        // already shows the new value, so reloading would only cause flicker.
        // hasChangedSinceLastSnapshot() already advanced its snapshot, which
        // consumes the change.
        if let tweaksWriteCoordinator, await tweaksWriteCoordinator.isInSuppressionWindow() {
          inspectorLog.debug("Skipping auto reload for tweaks persistence write")
          continue
        }
        inspectorLog.debug("Detected project file changes; scheduling embedded preview hard reload")
        try? await Task.sleep(for: .milliseconds(150))
        _ = await observer.hasChangedSinceLastSnapshot()
        guard !Task.isCancelled else { return }
        autoReloadPreview()
      }
    }
  }

  private func configureInspectorViewModelForCurrentProject() async {
    guard let normalizedProjectPath,
          let projectFileProvider else {
      if let inspectorViewModel {
        await inspectorViewModel.flushPendingWriteIfNeeded()
      }
      inspectorViewModel = nil
      await tweaksWriteCoordinator?.flush()
      tweaksWriteCoordinator = nil
      return
    }

    guard inspectorViewModel?.projectPath != normalizedProjectPath else { return }

    if let inspectorViewModel {
      await inspectorViewModel.flushPendingWriteIfNeeded()
    }
    await tweaksWriteCoordinator?.flush()

    inspectorViewModel = WebPreviewInspectorViewModel(
      projectPath: normalizedProjectPath,
      sourceResolver: WebPreviewSourceResolver(fileService: projectFileProvider),
      fileService: projectFileProvider,
      recentActivityProvider: recentActivityProvider
    )
    tweaksWriteCoordinator = TweaksDefaultsWriteCoordinator(
      projectPath: normalizedProjectPath,
      fileService: projectFileProvider
    )

    if let previewWebView {
      attachInspectorViewModel(to: previewWebView)
    }
  }

  private static func normalizedProjectPath(_ path: String?) -> String? {
    let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else { return nil }
    return URL(fileURLWithPath: trimmed).standardizedFileURL.resolvingSymlinksInPath().path
  }

  private static let consoleHookScript = """
    (function() {
      if (window.__easelConsoleHookInstalled) { return; }
      window.__easelConsoleHookInstalled = true;

      function serialize(value) {
        if (typeof value === 'string') { return value; }
        try { return JSON.stringify(value); } catch (error) { return String(value); }
      }

      ['log', 'warn', 'error'].forEach(function(level) {
        var original = console[level];
        console[level] = function() {
          var parts = Array.from(arguments).map(serialize).join(' ');
          try {
            window.webkit.messageHandlers.easelConsole.postMessage({
              level: level,
              message: parts
            });
          } catch (error) {}
          return original.apply(console, arguments);
        };
      });
    })();
  """
}

private struct InspectOverlayCursorModifier: ViewModifier {
  let label: String
  let onHoverChange: (Bool) -> Void
  @State private var isHovering = false

  func body(content: Content) -> some View {
    content
      .onHover { hovering in
        updateCursor(isHovering: hovering)
        onHoverChange(hovering)
      }
      .onDisappear {
        updateCursor(isHovering: false)
        onHoverChange(false)
      }
  }

  private func updateCursor(isHovering: Bool) {
    guard isHovering != self.isHovering else { return }
    self.isHovering = isHovering
    if isHovering {
      NSCursor.arrow.push()
    } else {
      NSCursor.pop()
    }
  }
}

private extension View {
  func inspectOverlayCursor(label: String, onHoverChange: @escaping (Bool) -> Void) -> some View {
    modifier(InspectOverlayCursorModifier(label: label, onHoverChange: onHoverChange))
  }
}
