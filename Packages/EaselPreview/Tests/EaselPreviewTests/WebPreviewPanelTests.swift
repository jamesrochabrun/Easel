//
//  WebPreviewPanelTests.swift
//  EaselPreviewTests
//

import EaselKit
import Testing

@MainActor
final class MockInspectorBridge: InspectorBridgeProtocol {
  var lastInspectorPrompt: String?
  var lastContextPrompt: String?
  var lastCropPrompt: String?

  func sendInspectorPrompt(_ prompt: String) {
    lastInspectorPrompt = prompt
  }

  func sendContextPrompt(_ prompt: String) {
    lastContextPrompt = prompt
  }

  func sendCropPrompt(_ prompt: String) {
    lastCropPrompt = prompt
  }
}

@MainActor
final class MockPreviewURLProvider: PreviewURLProviding {
  var previewURL: URL?
}

@MainActor
struct WebPreviewPanelTests {

  @Test
  func mockInspectorBridgeRecordsPrompts() {
    let bridge = MockInspectorBridge()
    bridge.sendInspectorPrompt("test inspector")
    bridge.sendContextPrompt("test context")
    bridge.sendCropPrompt("test crop")

    #expect(bridge.lastInspectorPrompt == "test inspector")
    #expect(bridge.lastContextPrompt == "test context")
    #expect(bridge.lastCropPrompt == "test crop")
  }

  @Test
  func mockPreviewURLProviderDefaultsToNil() {
    let provider = MockPreviewURLProvider()
    #expect(provider.previewURL == nil)
  }

  @Test
  func mockPreviewURLProviderCanBeSet() {
    let provider = MockPreviewURLProvider()
    provider.previewURL = URL(string: "http://localhost:3000")
    #expect(provider.previewURL?.absoluteString == "http://localhost:3000")
  }
}
