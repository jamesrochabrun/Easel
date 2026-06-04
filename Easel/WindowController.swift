//
//  WindowController.swift
//  Easel
//

import AppKit
import EaselChat
import EaselKit
import SwiftUI

@MainActor
final class WindowController: NSObject, WindowControlling, NSWindowDelegate {
  let capsulePanel: NSPanel
  let canvasWindow: NSWindow

  private let appState: AppState
  private let chatService: ChatService
  private var storedCanvasFrame: NSRect?
  private var transitionGeneration = 0

  init(appState: AppState, chatService: ChatService, observesPhaseChanges: Bool = true) {
    self.appState = appState
    self.chatService = chatService
    self.capsulePanel = Self.makeCapsulePanel()
    self.canvasWindow = Self.makeCanvasWindow()

    super.init()

    configureCapsulePanel()
    configureCanvasWindow()

    if observesPhaseChanges {
      startObserving()
    }
  }

  func showCapsule() {
    let frame = capsuleFrame()
    capsulePanel.setFrame(frame, display: true)
    capsulePanel.alphaValue = 1
    canvasWindow.orderOut(nil)
    capsulePanel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func hideCapsule() {
    capsulePanel.orderOut(nil)
  }

  func showCanvas() {
    let targetFrame = storedCanvasFrame ?? canvasFrame()

    _ = nextTransitionGeneration()
    configureCanvasContent()
    canvasWindow.setFrame(targetFrame, display: true)
    canvasWindow.alphaValue = 1
    capsulePanel.orderOut(nil)
    capsulePanel.alphaValue = 1
    canvasWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func animateToCanvas() {
    let generation = nextTransitionGeneration()
    let targetFrame = storedCanvasFrame ?? canvasFrame()
    let startFrame = capsulePanel.isVisible ? capsulePanel.frame : capsuleFrame()

    configureCanvasContent()
    canvasWindow.setFrame(startFrame, display: false)
    canvasWindow.alphaValue = 0
    canvasWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    NSAnimationContext.runAnimationGroup { context in
      context.duration = WindowMetrics.animationDuration
      context.timingFunction = WindowMetrics.timingFunction
      context.allowsImplicitAnimation = true

      capsulePanel.animator().alphaValue = 0
      canvasWindow.animator().alphaValue = 1
      canvasWindow.animator().setFrame(targetFrame, display: true)
    } completionHandler: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard self.transitionGeneration == generation, self.appState.phase == .canvas else { return }

        self.storedCanvasFrame = self.canvasWindow.frame
        self.capsulePanel.orderOut(nil)
        self.capsulePanel.alphaValue = 1
        self.canvasWindow.makeKeyAndOrderFront(nil)
      }
    }
  }

  func animateToCapsule() {
    let generation = nextTransitionGeneration()
    preserveCanvasFrameIfPossible()

    let targetFrame = capsuleFrame()
    let frameToRestore = storedCanvasFrame ?? canvasFrame()

    capsulePanel.setFrame(targetFrame, display: false)
    capsulePanel.alphaValue = 0
    capsulePanel.makeKeyAndOrderFront(nil)

    NSAnimationContext.runAnimationGroup { context in
      context.duration = WindowMetrics.animationDuration
      context.timingFunction = WindowMetrics.timingFunction
      context.allowsImplicitAnimation = true

      canvasWindow.animator().alphaValue = 0
      canvasWindow.animator().setFrame(targetFrame, display: true)
      capsulePanel.animator().alphaValue = 1
    } completionHandler: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard self.transitionGeneration == generation, self.appState.phase == .capsule else { return }

        self.canvasWindow.orderOut(nil)
        self.canvasWindow.contentView = nil
        self.canvasWindow.alphaValue = 1
        self.canvasWindow.setFrame(frameToRestore, display: false)
        self.capsulePanel.makeKeyAndOrderFront(nil)
      }
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard sender === canvasWindow else { return true }

    preserveCanvasFrameIfPossible()
    appState.resetToCapsule()
    return false
  }

  private static func makeCapsulePanel() -> NSPanel {
    let panel = KeyablePanel(
      contentRect: .zero,
      styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    return panel
  }

  private static func makeCanvasWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: true
    )
    window.title = "Codex Design"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.fullScreenPrimary]
    return window
  }

  private func configureCapsulePanel() {
    let rootView = CapsuleInputView(appState: appState) { [weak self] in
      self?.hideCapsule()
    }
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.translatesAutoresizingMaskIntoConstraints = true
    hostingView.autoresizingMask = [.width, .height]
    capsulePanel.contentView = hostingView

    if let contentView = capsulePanel.contentView {
      contentView.wantsLayer = true
      contentView.layer?.cornerRadius = WindowMetrics.capsuleCornerRadius
      contentView.layer?.masksToBounds = true
    }
  }

  private func configureCanvasWindow() {
    canvasWindow.delegate = self
  }

  private func configureCanvasContent() {
    let hostingView = NSHostingView(
      rootView: CanvasContentView(
        appState: appState,
        initialPrompt: appState.promptText,
        chatService: chatService
      )
    )
    hostingView.translatesAutoresizingMaskIntoConstraints = true
    hostingView.autoresizingMask = [.width, .height]
    canvasWindow.contentView = hostingView
  }

  private func startObserving() {
    withObservationTracking {
      _ = appState.phase
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.handlePhaseChange()
        self.startObserving()
      }
    }
  }

  private func handlePhaseChange() {
    switch appState.phase {
    case .capsule:
      animateToCapsule()
    case .canvas:
      animateToCanvas()
    }
  }

  private func preserveCanvasFrameIfPossible() {
    guard canvasWindow.isVisible else { return }
    guard canvasWindow.frame.height > WindowMetrics.capsuleHeight * 2 else { return }
    storedCanvasFrame = canvasWindow.frame
  }

  private func nextTransitionGeneration() -> Int {
    transitionGeneration += 1
    return transitionGeneration
  }

  private func capsuleFrame() -> NSRect {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let x = screenFrame.midX - WindowMetrics.capsuleWidth / 2
    let y = screenFrame.minY + screenFrame.height * 0.6 - WindowMetrics.capsuleHeight / 2
    return NSRect(
      x: x,
      y: y,
      width: WindowMetrics.capsuleWidth,
      height: WindowMetrics.capsuleHeight
    )
  }

  private func canvasFrame() -> NSRect {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let x = screenFrame.midX - WindowMetrics.canvasWidth / 2
    let y = screenFrame.midY - WindowMetrics.canvasHeight / 2
    return NSRect(
      x: x,
      y: y,
      width: WindowMetrics.canvasWidth,
      height: WindowMetrics.canvasHeight
    )
  }
}
