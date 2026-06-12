//
//  CodexChatRuntimeGenerationTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

/// Guards the generation-token semantics that stop a still-streaming Codex turn
/// from bleeding into a new session/workspace after the user switches away
/// mid-generation. `send` captures the token at the start of a turn; if it no
/// longer matches when events arrive or the turn finishes, the turn is dropped.
final class CodexChatRuntimeGenerationTests: XCTestCase {
  @MainActor
  func testCancelInvalidatesActiveTurn() {
    let runtime = makeRuntime()
    let captured = runtime.activeGeneration

    runtime.cancel()

    // A turn that captured `captured` is now stale and must not mutate state.
    XCTAssertNotEqual(runtime.activeGeneration, captured)
  }

  @MainActor
  func testResetSessionInvalidatesActiveTurn() {
    let runtime = makeRuntime()
    let captured = runtime.activeGeneration

    runtime.resetSession()

    XCTAssertNotEqual(runtime.activeGeneration, captured)
  }

  @MainActor
  func testEachInvalidationAdvancesTheToken() {
    let runtime = makeRuntime()
    let start = runtime.activeGeneration

    runtime.cancel()
    runtime.resetSession()
    runtime.cancel()

    // Three invalidations → three distinct advances, never reused.
    XCTAssertGreaterThanOrEqual(runtime.activeGeneration, start + 3)
  }

  @MainActor
  private func makeRuntime() -> CodexChatRuntime {
    CodexChatRuntime(
      messageDisplay: MessageStore(),
      sessionManager: SessionManager(sessionStorage: NoOpSessionStorage()),
      workingDirectory: "/tmp/easel",
      onSessionChange: nil
    )
  }
}
