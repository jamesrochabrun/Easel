//
//  WindowControllerTests.swift
//  EaselTests
//

import AppKit
import EaselKit
import Testing
@testable import Easel

@MainActor
struct WindowControllerTests {

  @Test
  func capsuleUsesPanelAndCanvasUsesNativeWindow() {
    let appState = AppState()
    let controller = WindowController(appState: appState, observesPhaseChanges: false)

    #expect(controller.capsulePanel.styleMask.contains(.nonactivatingPanel))
    #expect(controller.capsulePanel.level == .floating)
    #expect(controller.canvasWindow.styleMask.contains(.titled))
    #expect(controller.canvasWindow.styleMask.contains(.closable))
    #expect(controller.canvasWindow.styleMask.contains(.miniaturizable))
    #expect(controller.canvasWindow.styleMask.contains(.resizable))
    #expect(!controller.canvasWindow.styleMask.contains(.nonactivatingPanel))
    #expect(controller.canvasWindow.delegate === controller)
    #expect(!controller.canvasWindow.isReleasedWhenClosed)
  }

  @Test
  func closingCanvasWindowReturnsToCapsuleWithoutClosingWindow() {
    let appState = AppState()
    appState.phase = .canvas
    let controller = WindowController(appState: appState, observesPhaseChanges: false)

    let shouldClose = controller.windowShouldClose(controller.canvasWindow)

    #expect(!shouldClose)
    #expect(appState.phase == .capsule)
  }

  @Test
  func canvasContentUsesSubmittedPromptSnapshot() {
    let appState = AppState()
    appState.promptText = "Build a dashboard"

    let view = CanvasContentView(appState: appState, initialPrompt: appState.promptText)
    appState.promptText = "Edited later"

    #expect(view.initialPrompt == "Build a dashboard")
  }
}
