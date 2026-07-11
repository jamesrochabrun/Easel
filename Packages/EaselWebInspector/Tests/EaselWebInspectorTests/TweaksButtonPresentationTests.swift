//
//  TweaksButtonPresentationTests.swift
//  EaselWebInspectorTests
//

import Canvas
import Testing
@testable import EaselWebInspector

@Suite("TweaksButtonPresentation")
struct TweaksButtonPresentationTests {
  @Test("Working state shows progress")
  func workingStateShowsProgress() {
    let presentation = TweaksButtonPresentation.resolve(agentState: .working)

    #expect(presentation.isLoading)
    #expect(presentation.accessibilityLabel == "Creating tweaks")
  }

  @Test("Non-working states use the standard label", arguments: [
    TweaksAgentState.idle,
    .failed("Something went wrong"),
    .conflict,
  ])
  func nonWorkingStatesUseStandardLabel(agentState: TweaksAgentState) {
    let presentation = TweaksButtonPresentation.resolve(agentState: agentState)

    #expect(!presentation.isLoading)
    #expect(presentation.accessibilityLabel == "Tweaks")
  }
}
