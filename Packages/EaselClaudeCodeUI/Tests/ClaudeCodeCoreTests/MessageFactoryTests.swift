//
//  MessageFactoryTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class MessageFactoryTests: XCTestCase {
  func testThinkingMessageUsesProviderContentWithoutAddingVisibleLabel() {
    let message = MessageFactory.thinkingMessage(content: "Evaluating files")

    XCTAssertEqual(message.role, .thinking)
    XCTAssertEqual(message.messageType, .thinking)
    XCTAssertEqual(message.content, "Evaluating files")
  }

  func testEmptyThinkingMessageStaysEmpty() {
    let message = MessageFactory.thinkingMessage(content: "")

    XCTAssertEqual(message.content, "")
  }
}
