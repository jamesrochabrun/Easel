//
//  PreviewURLObserverTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import Foundation
import Testing
@testable import EaselChat

struct MockURLExtractor: URLExtracting {
  var urlToReturn: URL?

  func extractPreviewURL(from text: String) -> URL? {
    if text.contains("localhost") {
      return urlToReturn
    }
    return nil
  }
}

@MainActor
struct PreviewURLObserverTests {

  @Test
  func initialStateNotObserving() {
    let observer = PreviewURLObserver()
    // Should not crash when stopping without starting
    observer.stopObserving()
  }

  @Test
  func extractorProtocolConformance() {
    let extractor = LocalhostURLExtractor()
    let result = extractor.extractPreviewURL(from: "http://localhost:3000")
    #expect(result?.absoluteString == "http://localhost:3000")
  }

  @Test
  func mockExtractorReturnsConfiguredURL() {
    let mock = MockURLExtractor(urlToReturn: URL(string: "http://localhost:8080"))
    let result = mock.extractPreviewURL(from: "Running on localhost")
    #expect(result?.absoluteString == "http://localhost:8080")
  }

  @Test
  func mockExtractorReturnsNilForNonMatchingText() {
    let mock = MockURLExtractor(urlToReturn: URL(string: "http://localhost:8080"))
    let result = mock.extractPreviewURL(from: "No URL here")
    #expect(result == nil)
  }

  @Test
  func scanExistingMessagesFindsURLInToolResult() {
    let observer = PreviewURLObserver(
      extractor: LocalhostURLExtractor()
    )
    let messages: [ChatMessage] = [
      ChatMessage(role: .user, content: "start the dev server"),
      ChatMessage(
        role: .assistant,
        content: "Server output: http://localhost:4360/AgentHubPage",
        messageType: .toolResult
      ),
    ]
    let result = observer.scanExistingMessages(messages)
    #expect(result?.absoluteString == "http://localhost:4360/AgentHubPage")
  }

  @Test
  func scanExistingMessagesReturnsNilWhenNoURL() {
    let observer = PreviewURLObserver(
      extractor: LocalhostURLExtractor()
    )
    let messages: [ChatMessage] = [
      ChatMessage(role: .user, content: "hello"),
      ChatMessage(role: .assistant, content: "Hi there!"),
    ]
    let result = observer.scanExistingMessages(messages)
    #expect(result == nil)
  }

  @Test
  func scanExistingMessagesPrefersToolResultOverText() {
    let observer = PreviewURLObserver(
      extractor: LocalhostURLExtractor()
    )
    let messages: [ChatMessage] = [
      ChatMessage(
        role: .assistant,
        content: "Check out http://localhost:3000/old",
        messageType: .text
      ),
      ChatMessage(
        role: .assistant,
        content: "Local: http://localhost:4360/AgentHubPage",
        messageType: .toolResult
      ),
    ]
    let result = observer.scanExistingMessages(messages)
    #expect(result?.absoluteString == "http://localhost:4360/AgentHubPage")
  }
}
