//
//  PanelController.swift
//  Easel
//

import AppKit
import EaselKit
import SwiftUI

// MARK: - Constants

private enum PanelMetrics {
  static let capsuleWidth: CGFloat = 600
  static let capsuleHeight: CGFloat = 56
  static let capsuleCornerRadius: CGFloat = 28

  static let canvasWidth: CGFloat = 1200
  static let canvasHeight: CGFloat = 800
  static let canvasCornerRadius: CGFloat = 12

  static let animationDuration: CGFloat = 0.5
}

// MARK: - KeyablePanel

private class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

// MARK: - PanelController

@MainActor
final class PanelController: PanelControlling {
  private let panel: NSPanel
  private let appState: AppState

  init(appState: AppState) {
    self.appState = appState

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

    self.panel = panel

    let hostingView = NSHostingView(rootView: RootContentView(appState: appState))
    hostingView.translatesAutoresizingMaskIntoConstraints = true
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    if let contentView = panel.contentView {
      contentView.wantsLayer = true
      contentView.layer?.cornerRadius = PanelMetrics.capsuleCornerRadius
      contentView.layer?.masksToBounds = true
    }

    startObserving()
  }

  // MARK: - Public

  func showCapsule() {
    let frame = capsuleFrame()
    panel.setFrame(frame, display: true)
    panel.contentView?.layer?.cornerRadius = PanelMetrics.capsuleCornerRadius
    panel.level = .floating
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func animateToCanvas() {
    let targetFrame = canvasFrame()

    // Update window behavior for canvas mode
    panel.styleMask.remove(.nonactivatingPanel)
    panel.level = .normal
    panel.collectionBehavior = [.fullScreenPrimary]

    NSAnimationContext.runAnimationGroup { context in
      context.duration = PanelMetrics.animationDuration
      context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.3, 1.0)
      context.allowsImplicitAnimation = true

      panel.animator().setFrame(targetFrame, display: true)
      panel.contentView?.layer?.cornerRadius = PanelMetrics.canvasCornerRadius
    }
  }

  func animateToCapsule() {
    let targetFrame = capsuleFrame()

    NSAnimationContext.runAnimationGroup { context in
      context.duration = PanelMetrics.animationDuration
      context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.3, 1.0)
      context.allowsImplicitAnimation = true

      panel.animator().setFrame(targetFrame, display: true)
      panel.contentView?.layer?.cornerRadius = PanelMetrics.capsuleCornerRadius
    } completionHandler: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.panel.styleMask.insert(.nonactivatingPanel)
        self.panel.level = .floating
        self.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      }
    }
  }

  // MARK: - Observation

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

  // MARK: - Frame Calculations

  private func capsuleFrame() -> NSRect {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let x = screenFrame.midX - PanelMetrics.capsuleWidth / 2
    // Position at roughly 1/3 from top (like Spotlight)
    let y = screenFrame.minY + screenFrame.height * 0.6 - PanelMetrics.capsuleHeight / 2
    return NSRect(
      x: x,
      y: y,
      width: PanelMetrics.capsuleWidth,
      height: PanelMetrics.capsuleHeight
    )
  }

  private func canvasFrame() -> NSRect {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let x = screenFrame.midX - PanelMetrics.canvasWidth / 2
    let y = screenFrame.midY - PanelMetrics.canvasHeight / 2
    return NSRect(
      x: x,
      y: y,
      width: PanelMetrics.canvasWidth,
      height: PanelMetrics.canvasHeight
    )
  }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var panelController: PanelController?
  let appState = AppState()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = PanelController(appState: appState)
    self.panelController = controller
    controller.showCapsule()
  }
}
