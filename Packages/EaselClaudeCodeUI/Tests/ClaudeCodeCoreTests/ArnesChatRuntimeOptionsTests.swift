//
//  ArnesChatRuntimeOptionsTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class ArnesChatRuntimeOptionsTests: XCTestCase {
  func testFirstTurnPersistsSessionAndStreamsJSON() {
    let arguments = ArnesChatRuntime.makeArguments(
      executable: "/opt/homebrew/bin/arnes",
      resumeSessionId: nil,
      modelIdentifier: "anthropic/claude-sonnet-4.5"
    )

    XCTAssertEqual(arguments, [
      "do", "-", "--yes", "--output-format", "stream-json", "--include-partial",
      "--session",
      "-m", "anthropic/claude-sonnet-4.5",
    ])
  }

  func testSubsequentTurnResumesSession() {
    let arguments = ArnesChatRuntime.makeArguments(
      executable: "/opt/homebrew/bin/arnes",
      resumeSessionId: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8",
      modelIdentifier: nil
    )

    XCTAssertEqual(arguments, [
      "do", "-", "--yes", "--output-format", "stream-json", "--include-partial",
      "--resume", "6BA7B810-9DAD-11D1-80B4-00C04FD430C8",
    ])
    XCTAssertFalse(arguments.contains("--session"))
  }

  func testAutoModelSendsNoModelFlag() {
    for model in [nil, "", "  ", "openrouter/auto"] {
      let arguments = ArnesChatRuntime.makeArguments(
        executable: "/opt/homebrew/bin/arnes",
        resumeSessionId: nil,
        modelIdentifier: model
      )
      XCTAssertFalse(arguments.contains("-m"), "expected no -m for model \(model ?? "nil")")
    }
  }

  func testSystemInstructionsAndExtraArgumentsAreAppended() {
    let arguments = ArnesChatRuntime.makeArguments(
      executable: "/opt/homebrew/bin/arnes",
      resumeSessionId: nil,
      modelIdentifier: nil,
      systemInstructions: "Answer in bullets.",
      extraArguments: ["--effort", "high"]
    )

    XCTAssertTrue(arguments.contains("--append-system-prompt"))
    XCTAssertTrue(arguments.contains("Answer in bullets."))
    XCTAssertEqual(arguments.suffix(2), ["--effort", "high"])
  }

  func testEnvFallbackPrefixesArnesCommand() {
    let arguments = ArnesChatRuntime.makeArguments(
      executable: "/usr/bin/env",
      resumeSessionId: nil,
      modelIdentifier: nil
    )

    XCTAssertEqual(arguments.first, "arnes")
    XCTAssertEqual(arguments[1], "do")
  }

  func testNormalizedModelIdentifier() {
    XCTAssertNil(ArnesChatRuntime.normalizedModelIdentifier(nil))
    XCTAssertNil(ArnesChatRuntime.normalizedModelIdentifier(""))
    XCTAssertNil(ArnesChatRuntime.normalizedModelIdentifier("  "))
    XCTAssertNil(ArnesChatRuntime.normalizedModelIdentifier("openrouter/auto"))
    XCTAssertEqual(
      ArnesChatRuntime.normalizedModelIdentifier(" openai/gpt-6.1-sol "),
      "openai/gpt-6.1-sol"
    )
  }
}
