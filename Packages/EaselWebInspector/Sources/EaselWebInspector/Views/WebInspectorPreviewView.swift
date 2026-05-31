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
  @State private var queueSendFailureMessage: String?
  @State private var isLoading = false
  @Environment(\.colorScheme) private var colorScheme

  private var isAdvancedEditingEnabled: Bool {
    projectFileProvider != nil
  }

  private var showsInspectorRail: Bool {
    isAdvancedEditingEnabled && inspectBehavior == .edit && (inspectorViewModel?.isPanelVisible ?? false)
  }

  private var updateState: WebPreviewUpdateState {
    WebPreviewUpdateState.resolve(
      hasPreview: previewURLProvider.previewURL != nil,
      isEditMode: isAdvancedEditingEnabled && inspectBehavior == .edit
    )
  }

  private var activeSelectorToRestore: String? {
    guard !scrollRestorationCoordinator.suppressesSelectorRestore else { return nil }
    return lastSelectedSelector
  }

  public init(
    previewURLProvider: PreviewURLProviding,
    inspectorBridge: InspectorBridgeProtocol,
    projectFileProvider: (any ProjectFileProviding)? = nil,
    recentActivityProvider: (any RecentActivityProviding)? = nil
  ) {
    self.previewURLProvider = previewURLProvider
    self.inspectorBridge = inspectorBridge
    self.projectFileProvider = projectFileProvider
    self.recentActivityProvider = recentActivityProvider
  }

  public var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      content
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
    .onChange(of: inspectBehavior) { _, newBehavior in
      guard inspectState.isActive else { return }
      inspectState.activate(mode: newBehavior.canvasMode)
      if let inspectorViewModel {
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
      Button {
        toggleInspector()
      } label: {
        Image(systemName: "cursorarrow.rays")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(inspectState.isActive ? EaselDesignSystem.Palette.accent : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
      .buttonStyle(.plain)
      .help("\(inspectState.isActive ? "Stop" : "Start") \(inspectBehavior.modeName) mode")

      if inspectState.isActive {
        let availableModes = WebPreviewInspectBehavior.availableCases(advancedEditingEnabled: isAdvancedEditingEnabled)
        if availableModes.count > 1 {
          HStack(spacing: 6) {
            ForEach(availableModes) { behavior in
              Button {
                inspectBehavior = behavior
              } label: {
                Image(systemName: behavior.icon)
                  .font(.caption)
                  .frame(width: 26, height: 20)
                  .foregroundStyle(inspectBehavior == behavior ? EaselDesignSystem.Palette.accent : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(behavior.accessibilityLabel)
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
        Button("") { toggleInspector() }
          .keyboardShortcut("i", modifiers: [.command, .shift])
        Button("") { refreshPreview() }
          .keyboardShortcut("r", modifiers: .command)
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
    } else {
      placeholderView
    }
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
    InspectableWebView(
      url: url,
      isFileURL: isFileURL,
      inspectorDataLevel: .regular,
      onLoadingChange: { loading in
        isLoading = loading
      },
      onURLChange: { _ in },
      onError: { _ in },
      reloadToken: reloadToken,
      onElementSelected: { element in
        handleElementSelected(element)
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
      onWebViewReady: { webView in
        // Defer the state assignment past the current view update cycle,
        // otherwise SwiftUI discards the change with a "Modifying state
        // during view update" warning.
        Task { @MainActor in
          previewWebView = webView
        }
        inspectorViewModel?.registerWebView(webView)
        setupConsoleCapture(webView: webView)
      }
    )
    .webInspectorOverlay(
      state: inspectState,
      inputPlacement: .selectionAnchored,
      onSubmit: { element, instruction in
        handleInspectSubmit(element: element, instruction: instruction)
      },
      onContextSelection: { element in
        handleContextSelection(element: element)
      },
      onCropSubmit: { rect, elements, instruction in
        handleCropSubmit(rect: rect, elements: elements, instruction: instruction)
      },
      deactivateOnSubmit: false
    )
  }

  // MARK: - Actions

  private func toggleInspector() {
    if inspectState.isActive {
      deactivateInspector()
    } else {
      inspectState.activate(mode: inspectBehavior.canvasMode)
    }
  }

  private func deactivateInspector() {
    inspectState.deactivate()
  }

  private func refreshPreview() {
    manualReloadToken = UUID()
    scrollRestorationCoordinator.reset(to: manualReloadToken)
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
    // The onChange observer on cropRect will call
    // ElementInspectorBridge.clearCropSelection to remove the JS visual.
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
      Task {
        await inspectorViewModel.inspect(element: element, previewFilePath: nil)
      }
    }
  }

  private func handleInspectSubmit(element: ElementInspectorData, instruction: String) {
    localContextQueue.append(element, instruction: instruction)
    inspectState.dismissInput()
  }

  private func handleContextSelection(element: ElementInspectorData) {
    localContextQueue.append(element)
    inspectState.dismissInput()
  }

  private func handleCropSubmit(rect: CGRect, elements: [ElementInspectorData], instruction: String) {
    inspectorLog.debug("handleCropSubmit called rect=\(rect.debugDescription) elements=\(elements.count)")

    Task { @MainActor in
      var screenshotPath: String? = nil
      if let webView = previewWebView {
        inspectorLog.debug("Capturing screenshot via ElementSnapshotCapture, webView bounds=\(webView.bounds.debugDescription)")
        if let image = try? await ElementSnapshotCapture.captureSnapshot(of: rect, in: webView) {
          inspectorLog.debug("Snapshot succeeded, size=\(NSStringFromSize(image.size))")
          screenshotPath = saveCropScreenshot(image)
        } else {
          inspectorLog.error("ElementSnapshotCapture.captureSnapshot returned nil or threw")
        }
      } else {
        inspectorLog.error("previewWebView is nil at crop submit time")
      }

      inspectorLog.debug("Appending crop to queue, screenshotPath=\(screenshotPath ?? "nil")")
      localContextQueue.appendCrop(
        cropRect: rect,
        elements: elements,
        instruction: instruction,
        screenshotPath: screenshotPath
      )
    }
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
    guard let prompt = localContextQueue.composedContextPrompt() else { return }

    // Prepend screenshot paths so Claude Code detects and attaches them as images.
    let screenshotPaths = localContextQueue.screenshotPaths()
    let finalPrompt: String
    if screenshotPaths.isEmpty {
      finalPrompt = prompt
    } else {
      let pathsPrefix = screenshotPaths
        .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
        .joined(separator: " ")
      finalPrompt = "\(pathsPrefix) \(prompt)"
    }

    inspectorBridge.sendInspectorPrompt(finalPrompt)
    localContextQueue.clear()
    queueSendFailureMessage = nil
  }

  private func setupConsoleCapture(webView: WKWebView) {
    consoleMessageHandler.onMessage = { [weak inspectorViewModel] level, message in
      Task { @MainActor in
        inspectorViewModel?.appendConsoleEntry(level: level, message: message)
      }
    }
  }

}

// MARK: - ViewModel Initialization

extension WebInspectorPreviewView {
  func ensureInspectorViewModel() -> WebPreviewInspectorViewModel? {
    guard let projectFileProvider else { return nil }
    if let existing = inspectorViewModel { return existing }
    let vm = WebPreviewInspectorViewModel(
      projectPath: "",
      sourceResolver: WebPreviewSourceResolver(fileService: projectFileProvider),
      fileService: projectFileProvider,
      recentActivityProvider: recentActivityProvider
    )
    return vm
  }
}
