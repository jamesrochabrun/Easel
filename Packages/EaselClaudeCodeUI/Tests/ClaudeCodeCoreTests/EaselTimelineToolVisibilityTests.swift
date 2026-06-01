//
//  EaselTimelineToolVisibilityTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class EaselTimelineToolVisibilityTests: XCTestCase {
  func testFailedInternalToolResultIsHiddenFromTimeline() {
    let toolUse = ChatMessage(
      role: .toolUse,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "git status"])
    )
    let toolResult = ChatMessage(
      role: .toolError,
      content: "fatal: not a git repository",
      messageType: .toolError,
      toolName: "Bash"
    )

    XCTAssertTrue(EaselTimelineToolVisibility.shouldHideToolPair(
      toolUse: toolUse,
      toolResult: toolResult
    ))
    XCTAssertTrue(EaselTimelineToolVisibility.shouldHideToolResult(toolResult))
  }

  func testRunningAndCompletedToolsRemainVisible() {
    let toolUse = ChatMessage(
      role: .toolUse,
      content: "",
      messageType: .toolUse,
      toolName: "Read"
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "ok",
      messageType: .toolResult,
      toolName: "Read"
    )

    XCTAssertFalse(EaselTimelineToolVisibility.shouldHideToolPair(
      toolUse: toolUse,
      toolResult: nil
    ))
    XCTAssertFalse(EaselTimelineToolVisibility.shouldHideToolPair(
      toolUse: toolUse,
      toolResult: toolResult
    ))
    XCTAssertFalse(EaselTimelineToolVisibility.shouldHideToolResult(toolResult))
  }
}
