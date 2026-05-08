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
  }
}
