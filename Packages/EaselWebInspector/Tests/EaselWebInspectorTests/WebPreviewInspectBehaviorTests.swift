//
//  WebPreviewInspectBehaviorTests.swift
//  EaselWebInspectorTests
//

import Testing
@testable import EaselWebInspector

@Suite("WebPreviewInspectBehavior")
struct WebPreviewInspectBehaviorTests {
  @Test("Basic canvas modes match AgentHub user-facing queue modes")
  func basicModes() {
    #expect(WebPreviewInspectBehavior.availableCases(advancedEditingEnabled: false) == [.input, .crop])
  }

  @Test("Advanced canvas modes enable source edit mode")
  func advancedModes() {
    #expect(WebPreviewInspectBehavior.availableCases(advancedEditingEnabled: true) == [.input, .crop, .edit])
  }
}
