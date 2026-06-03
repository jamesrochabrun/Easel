//
//  CodexChatRuntimeOptionsTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class CodexChatRuntimeOptionsTests: XCTestCase {
  @MainActor
  func testFirstTurnSkipsGitRepoCheck() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      configOverrides: [:]
    )

    XCTAssertTrue(options.skipGitRepoCheck)
    XCTAssertEqual(options.changeDirectory, "/tmp/easel")
    XCTAssertTrue(options.jsonEvents)
  }

  @MainActor
  func testDeveloperInstructionsArePassedAsCodexConfigOverride() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      developerInstructions: "You are a frontend designer-agent.\nAlways update the embedded preview.",
      configOverrides: [:]
    )

    XCTAssertEqual(
      options.configOverrides["developer_instructions"],
      "\"You are a frontend designer-agent.\\nAlways update the embedded preview.\""
    )
  }

  @MainActor
  func testDeveloperInstructionsAreEscapedAsTomlString() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      developerInstructions: "line \"one\"\nline two",
      configOverrides: [:]
    )

    XCTAssertEqual(
      options.configOverrides["developer_instructions"],
      #""line \"one\"\nline two""#
    )
  }

  @MainActor
  func testResumeBySessionSkipsGitRepoCheck() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: "thread-id",
      workingDirectory: "/tmp/easel",
      configOverrides: [:]
    )

    XCTAssertTrue(options.skipGitRepoCheck)
    XCTAssertEqual(options.resumeSessionId, "thread-id")
    XCTAssertFalse(options.resumeLastSession)
    XCTAssertTrue(options.jsonEvents)
  }

  @MainActor
  func testResumeLastSkipsGitRepoCheck() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      configOverrides: [:]
    )

    XCTAssertTrue(options.skipGitRepoCheck)
    XCTAssertTrue(options.resumeLastSession)
    XCTAssertTrue(options.jsonEvents)
  }
}
