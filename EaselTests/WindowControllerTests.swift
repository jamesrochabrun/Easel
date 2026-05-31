//
//  WindowControllerTests.swift
//  EaselTests
//

import AppKit
import EaselChat
import EaselKit
import Testing
@testable import Easel

@MainActor
struct WindowControllerTests {

  @Test
  func capsuleUsesPanelAndCanvasUsesNativeWindow() {
    let appState = AppState()
    let controller = WindowController(
      appState: appState,
      chatService: ChatService(),
      observesPhaseChanges: false
    )

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
    let controller = WindowController(
      appState: appState,
      chatService: ChatService(),
      observesPhaseChanges: false
    )

    let shouldClose = controller.windowShouldClose(controller.canvasWindow)

    #expect(!shouldClose)
    #expect(appState.phase == .capsule)
  }

  @Test
  func hideCapsuleOrdersOutPanel() {
    let appState = AppState()
    let controller = WindowController(
      appState: appState,
      chatService: ChatService(),
      observesPhaseChanges: false
    )
    controller.showCapsule()
    #expect(controller.capsulePanel.isVisible)

    controller.hideCapsule()
    #expect(!controller.capsulePanel.isVisible)
  }

  @Test
  func canvasContentUsesSubmittedPromptSnapshot() {
    let appState = AppState()
    appState.promptText = "Build a dashboard"

    let view = CanvasContentView(
      appState: appState,
      initialPrompt: appState.promptText,
      chatService: ChatService()
    )
    appState.promptText = "Edited later"

    #expect(view.initialPrompt == "Build a dashboard")
  }
}
