//
//  LocalAgentTerminalLauncherTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class LocalAgentTerminalLauncherTests: XCTestCase {
  func testCodexArgumentsIncludeModelExtraArgumentsAndPrompt() {
    let request = LocalAgentLaunchRequest(
      provider: .codex,
      workingDirectory: "/tmp/easel",
      prompt: "Implement the design",
      command: "echo",
      codexModel: "gpt-5.5",
      extraArguments: ["--api-mode", "enterprise"]
    )

    XCTAssertEqual(
      TerminalLauncher.localAgentArguments(for: request),
      ["--model", "gpt-5.5", "--api-mode", "enterprise", "Implement the design"]
    )
  }

  func testClaudeArgumentsContainOnlyPrompt() {
    let request = LocalAgentLaunchRequest(
      provider: .claude,
      workingDirectory: "/tmp/easel",
      prompt: "Implement the design",
      command: "echo",
      codexModel: "ignored",
      extraArguments: ["--ignored"]
    )

    XCTAssertEqual(
      TerminalLauncher.localAgentArguments(for: request),
      ["Implement the design"]
    )
  }

  func testShellCommandEscapesProjectPathAndPrompt() throws {
    let request = LocalAgentLaunchRequest(
      provider: .claude,
      workingDirectory: "/tmp/easel project",
      prompt: "Read README.md\nImplement Bob's design",
      command: "echo",
      additionalPaths: ["/bin"]
    )

    let command = try TerminalLauncher.localAgentShellCommand(for: request)

    XCTAssertTrue(command.contains("cd '/tmp/easel project'"))
    XCTAssertTrue(command.contains("exec '/bin/echo'"))
    XCTAssertTrue(command.contains("'Read README.md\nImplement Bob'\\''s design'"))
  }

  func testScriptExportsEnvironmentAndFiltersInvalidNames() throws {
    let request = LocalAgentLaunchRequest(
      provider: .codex,
      workingDirectory: "/tmp/easel",
      prompt: "Implement",
      command: "echo",
      additionalPaths: ["/bin"],
      environment: [
        "VALID": "two words",
        "ALSO_VALID_2": "quote'value",
        "NOT-VALID": "ignored"
      ]
    )

    let script = try TerminalLauncher.localAgentScriptContent(for: request)

    XCTAssertTrue(script.contains("export ALSO_VALID_2='quote'\\''value'"))
    XCTAssertTrue(script.contains("export VALID='two words'"))
    XCTAssertFalse(script.contains("NOT-VALID"))
  }

  func testMissingWorkingDirectoryThrows() {
    let request = LocalAgentLaunchRequest(
      provider: .codex,
      workingDirectory: " ",
      prompt: "Implement",
      command: "echo"
    )

    XCTAssertThrowsError(try TerminalLauncher.localAgentShellCommand(for: request)) { error in
      XCTAssertEqual(error as? LocalAgentLaunchError, .missingWorkingDirectory)
    }
  }

  func testCodexLaunchDoesNotAddAutonomousPermissionFlags() throws {
    let request = LocalAgentLaunchRequest(
      provider: .codex,
      workingDirectory: "/tmp/easel",
      prompt: "Implement",
      command: "echo",
      additionalPaths: ["/bin"],
      codexModel: "gpt-5.5"
    )

    let script = try TerminalLauncher.localAgentScriptContent(for: request)

    XCTAssertFalse(script.contains("--full-auto"))
    XCTAssertFalse(script.contains("--dangerously-skip-permissions"))
    XCTAssertFalse(script.contains("--sandbox"))
    XCTAssertFalse(script.contains("-a never"))
  }
}
