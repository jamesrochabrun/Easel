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
  func testDeveloperInstructionsAreNotPassedToResumeOptions() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: "thread-id",
      workingDirectory: "/tmp/easel",
      developerInstructions: "You are a frontend designer-agent.",
      configOverrides: [:]
    )

    XCTAssertNil(options.configOverrides["developer_instructions"])
    XCTAssertEqual(options.resumeSessionId, "thread-id")
  }

  @MainActor
  func testSelectedModelIsPassedToFirstTurnOptions() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "gpt-5.4",
      configOverrides: [:]
    )

    XCTAssertEqual(options.model, "gpt-5.4")
  }

  @MainActor
  func testDebugCommandDescriptionIncludesModelFlagForFirstTurn() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel path",
      modelIdentifier: "gpt-5.4",
      configOverrides: [:]
    )

    let command = CodexChatRuntime.debugCommandDescription(options: options)

    XCTAssertTrue(command.contains("--model 'gpt-5.4'"))
    XCTAssertTrue(command.contains("--cd '/tmp/easel path'"))
    XCTAssertTrue(command.hasSuffix(" -"))
  }

  @MainActor
  func testSelectedModelIsPassedToResumeOptions() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: "thread-id",
      workingDirectory: "/tmp/easel",
      modelIdentifier: "gpt-5.4-mini",
      configOverrides: [:]
    )

    XCTAssertEqual(options.model, "gpt-5.4-mini")
    XCTAssertEqual(options.resumeSessionId, "thread-id")
  }

  @MainActor
  func testDebugCommandDescriptionIncludesModelFlagForResume() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: "thread-id",
      workingDirectory: "/tmp/easel",
      modelIdentifier: "gpt-5.4-mini",
      configOverrides: [:]
    )

    let command = CodexChatRuntime.debugCommandDescription(options: options)

    XCTAssertTrue(command.contains("codex exec resume 'thread-id'"))
    XCTAssertTrue(command.contains("--model 'gpt-5.4-mini'"))
  }

  @MainActor
  func testBlankSelectedModelIsIgnored() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      modelIdentifier: "   ",
      configOverrides: [:]
    )

    XCTAssertNil(options.model)
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
