//
//  AppStateTests.swift
//  EaselTests
//

import Testing
@testable import Easel

@MainActor
struct AppStateTests {

  @Test
  func initialPhaseIsCapsule() {
    let state = AppState()
    #expect(state.phase == .capsule)
  }

  @Test
  func submitPromptTransitionsToCanvas() {
    let state = AppState()
    state.promptText = "Build a landing page"
    state.submitPrompt()
    #expect(state.phase == .canvas)
  }

  @Test
  func submitEmptyPromptStaysInCapsule() {
    let state = AppState()
    state.promptText = ""
    state.submitPrompt()
    #expect(state.phase == .capsule)
  }

  @Test
  func submitWhitespaceOnlyStaysInCapsule() {
    let state = AppState()
    state.promptText = "   \n  "
    state.submitPrompt()
    #expect(state.phase == .capsule)
  }

  @Test
  func resetToCapsule() {
    let state = AppState()
    state.promptText = "Build something"
    state.submitPrompt()
    #expect(state.phase == .canvas)

    state.resetToCapsule()
    #expect(state.phase == .capsule)
  }

  @Test
  func promptTextPreservedAfterTransition() {
    let state = AppState()
    state.promptText = "Create a dashboard"
    state.submitPrompt()
    #expect(state.phase == .canvas)
    #expect(state.promptText == "Create a dashboard")
  }
}
