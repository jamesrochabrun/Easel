//
//  ClaudeChatRuntimeOptionsBuilderTests.swift
//  ClaudeCodeCoreTests
//

import ClaudeCodeSDK
import XCTest
@testable import ClaudeCodeCore

@MainActor
final class ClaudeChatRuntimeOptionsBuilderTests: XCTestCase {
  func testParsesCommaAndNewlineSeparatedToolPatterns() {
    let patterns = ClaudeToolPatternParser.parse("Bash(npm *), Read\nEdit\n\n")

    XCTAssertEqual(patterns, ["Bash(npm *)", "Read", "Edit"])
  }

  func testMapsClaudePreferencesIntoSDKOptions() {
    let preferences = makePreferences()
    preferences.claudeModel = " opus "
    preferences.claudeAllowedTools = "Read\nBash(npm *)"
    preferences.claudeDisallowedTools = "Bash(rm -rf *)"
    preferences.disallowedTools = ["Write", "Bash(rm -rf *)"]
    preferences.systemPrompt = "System"
    preferences.appendSystemPrompt = "Append"
    preferences.mcpConfigPath = "/tmp/mcp.json"

    let options = ClaudeChatRuntimeOptionsBuilder(
      globalPreferences: preferences,
      systemPromptPrefix: "Prefix"
    ).makeOptions()

    XCTAssertEqual(options.model, "opus")
    XCTAssertEqual(options.allowedTools, ["Read", "Bash(npm *)"])
    XCTAssertEqual(
      options.disallowedTools,
      ["Bash(rm -rf *)", "Write"] + ClaudeChatRuntimeOptionsBuilder.defaultDisallowedTools
    )
    XCTAssertEqual(options.systemPrompt, "System")
    XCTAssertEqual(options.appendSystemPrompt, "Prefix\nAppend")
    XCTAssertEqual(options.mcpConfigPath, "/tmp/mcp.json")
    XCTAssertEqual(options.permissionMode, .bypassPermissions)
  }

  func testEmptyClaudeModelUsesCLIDefault() {
    let preferences = makePreferences()
    preferences.claudeModel = " "

    let options = ClaudeChatRuntimeOptionsBuilder(
      globalPreferences: preferences,
      systemPromptPrefix: nil
    ).makeOptions()

    XCTAssertNil(options.model)
  }

  func testAlwaysDisallowsUnsupportedAskUserQuestionTool() {
    let preferences = makePreferences()

    let options = ClaudeChatRuntimeOptionsBuilder(
      globalPreferences: preferences,
      systemPromptPrefix: nil
    ).makeOptions()

    XCTAssertEqual(options.disallowedTools, ClaudeChatRuntimeOptionsBuilder.defaultDisallowedTools)
  }

  func testUnsupportedAskUserQuestionToolIsRemovedFromAllowedTools() {
    let preferences = makePreferences()
    preferences.claudeAllowedTools = "Read\nAskUserQuestion\naskuserquestion"
    preferences.claudeDisallowedTools = "AskUserQuestion"

    let options = ClaudeChatRuntimeOptionsBuilder(
      globalPreferences: preferences,
      systemPromptPrefix: nil
    ).makeOptions()

    XCTAssertEqual(options.allowedTools, ["Read"])
    XCTAssertEqual(options.disallowedTools, ClaudeChatRuntimeOptionsBuilder.defaultDisallowedTools)
  }

  private func makePreferences() -> GlobalPreferencesStorage {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClaudeChatRuntimeOptionsBuilderTests-\(UUID().uuidString)", isDirectory: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: root)
    }

    return GlobalPreferencesStorage(
      persistentManager: PersistentPreferencesManager(applicationSupportURL: root)
    )
  }
}
