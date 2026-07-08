import ClaudeCodeSDK
import CodexSDK
import EaselKit
import XCTest
@testable import ClaudeCodeCore

// MARK: - CodexClientFactoryTests

final class CodexClientFactoryTests: XCTestCase {

  func testCommandOverrideTakesPrecedence() {
    let configuration = CodexClientFactory.makeConfiguration(
      commandOverride: "/custom/bin/codex",
      environmentOverrides: [:],
      workingDirectory: "/tmp/project"
    )

    XCTAssertEqual(configuration.command, "/custom/bin/codex")
    XCTAssertEqual(configuration.workingDirectory, "/tmp/project")
    XCTAssertTrue(configuration.useLoginShell)
  }

  func testWhitespaceOnlyOverrideIsIgnored() {
    let configuration = CodexClientFactory.makeConfiguration(
      commandOverride: "   ",
      environmentOverrides: [:],
      workingDirectory: nil
    )

    // Falls through to auto-detection; must never end up empty or whitespace.
    XCTAssertFalse(configuration.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  func testEnvironmentOverridesWinAndBlankKeysAreDropped() {
    let configuration = CodexClientFactory.makeConfiguration(
      commandOverride: "codex",
      environmentOverrides: ["CODEX_HOME": "/tmp/codex-home", "  ": "dropped"],
      workingDirectory: nil
    )

    XCTAssertEqual(configuration.environment["CODEX_HOME"], "/tmp/codex-home")
    XCTAssertNil(configuration.environment["  "])
  }

  func testAdditionalPathsIncludeCommonToolLocations() {
    let configuration = CodexClientFactory.makeConfiguration(
      commandOverride: "codex",
      environmentOverrides: [:],
      workingDirectory: nil
    )

    XCTAssertTrue(configuration.additionalPaths.contains("/usr/local/bin"))
    XCTAssertTrue(configuration.additionalPaths.contains("/opt/homebrew/bin"))
  }
}

// MARK: - CodexBackgroundAgentRunnerTests

final class CodexBackgroundAgentRunnerTests: XCTestCase {

  func testMakeOptionsMatchesInteractiveFirstTurn() {
    let options = CodexBackgroundAgentRunner.makeOptions(
      workingDirectory: "/tmp/shadow",
      model: "gpt-5-codex",
      extraArguments: ["--flag", "value"],
      timeout: 600
    )

    XCTAssertEqual(options.sandbox, .workspaceWrite)
    XCTAssertEqual(options.approval, .never)
    XCTAssertTrue(options.fullAuto)
    XCTAssertEqual(options.changeDirectory, "/tmp/shadow")
    XCTAssertTrue(options.jsonEvents)
    XCTAssertTrue(options.promptViaStdin)
    XCTAssertTrue(options.skipGitRepoCheck)
    XCTAssertEqual(options.timeout, 600)
    XCTAssertEqual(options.model, "gpt-5-codex")
    XCTAssertEqual(options.extraFlags, ["--flag", "value"])
    XCTAssertNil(options.resumeSessionId)
    XCTAssertFalse(options.resumeLastSession)
  }

  func testMakeOptionsOmitsBlankModel() {
    let options = CodexBackgroundAgentRunner.makeOptions(
      workingDirectory: "/tmp/shadow",
      model: "  ",
      extraArguments: [],
      timeout: 600
    )

    XCTAssertNil(options.model)
  }

  func testActivityDescriptionForFileChangeEvent() throws {
    let event = try decodeEvent("""
    {
      "type": "item.completed",
      "item": {
        "id": "fc-1",
        "type": "file_change",
        "changes": [
          { "path": "/tmp/shadow/src/App.tsx", "kind": "update" }
        ]
      }
    }
    """)

    let activity = CodexBackgroundAgentRunner.activityDescription(for: .jsonEvent(event))
    XCTAssertEqual(activity, "Editing App.tsx")
  }

  func testActivityDescriptionFallsBackToLegacyFilePath() throws {
    let event = try decodeEvent("""
    {
      "type": "item.completed",
      "item": {
        "id": "fc-2",
        "type": "file_change",
        "file_path": "/tmp/shadow/index.html"
      }
    }
    """)

    let activity = CodexBackgroundAgentRunner.activityDescription(for: .jsonEvent(event))
    XCTAssertEqual(activity, "Editing index.html")
  }

  func testActivityDescriptionIgnoresNonFileChangeEvents() throws {
    let event = try decodeEvent("""
    {
      "type": "item.completed",
      "item": { "id": "m-1", "type": "agent_message", "text": "hello" }
    }
    """)

    XCTAssertNil(CodexBackgroundAgentRunner.activityDescription(for: .jsonEvent(event)))
    XCTAssertNil(CodexBackgroundAgentRunner.activityDescription(for: .stdout("plain")))
  }

  func testNormalizesTimeoutAndNonZeroExit() {
    XCTAssertEqual(
      CodexBackgroundAgentRunner.normalized(CodexExecError.timeout(600)) as? BackgroundAgentRunnerError,
      .timedOut
    )

    let nonZero = CodexBackgroundAgentRunner.normalized(
      CodexExecError.nonZeroExit(exitCode: 2, stderr: "boom")
    )
    guard case BackgroundAgentRunnerError.processFailed(let message)? =
      nonZero as? BackgroundAgentRunnerError else {
      return XCTFail("Expected processFailed, got \(nonZero)")
    }
    XCTAssertTrue(message.contains("2"))
    XCTAssertTrue(message.contains("boom"))
  }

  private func decodeEvent(_ json: String) throws -> CodexJSONEvent {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CodexJSONEvent.self, from: Data(json.utf8))
  }
}

// MARK: - ClaudeBackgroundAgentRunnerTests

final class ClaudeBackgroundAgentRunnerTests: XCTestCase {

  func testMakeOptionsMirrorsInteractivePermissions() {
    let options = ClaudeBackgroundAgentRunner.makeOptions(
      model: "claude-sonnet-5",
      timeout: 600,
      appendSystemPrompt: "prefix"
    )

    XCTAssertEqual(options.permissionMode, .bypassPermissions)
    XCTAssertEqual(options.maxTurns, 30)
    XCTAssertEqual(options.timeout, 600)
    XCTAssertEqual(options.model, "claude-sonnet-5")
    XCTAssertEqual(options.appendSystemPrompt, "prefix")
  }

  func testMakeOptionsOmitsEmptyModelAndPrompt() {
    let options = ClaudeBackgroundAgentRunner.makeOptions(
      model: "",
      timeout: 600,
      appendSystemPrompt: nil
    )

    XCTAssertNil(options.model)
    XCTAssertNil(options.appendSystemPrompt)
  }

  func testNormalizesTimeoutError() {
    XCTAssertEqual(
      ClaudeBackgroundAgentRunner.normalized(ClaudeCodeError.timeout(600)) as? BackgroundAgentRunnerError,
      .timedOut
    )

    struct OtherError: Error {}
    XCTAssertTrue(ClaudeBackgroundAgentRunner.normalized(OtherError()) is OtherError)
  }
}
