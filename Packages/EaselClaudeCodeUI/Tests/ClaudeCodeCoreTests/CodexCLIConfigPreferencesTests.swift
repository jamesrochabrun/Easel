import XCTest
@testable import ClaudeCodeCore

final class CodexCLIConfigPreferencesTests: XCTestCase {
  func testClaudeAIConfigFieldsRoundTripThroughCoding() throws {
    let original = GeneralPreferences(
      claudeModel: "opus",
      claudeEffort: "high",
      claudeAllowedTools: "Read\nBash(npm *)",
      claudeDisallowedTools: "Bash(rm -rf *)"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(GeneralPreferences.self, from: data)

    XCTAssertEqual(decoded.claudeModel, "opus")
    XCTAssertEqual(decoded.claudeEffort, "high")
    XCTAssertEqual(decoded.claudeAllowedTools, "Read\nBash(npm *)")
    XCTAssertEqual(decoded.claudeDisallowedTools, "Bash(rm -rf *)")
  }

  func testNewFieldsRoundTripThroughCoding() throws {
    let original = GeneralPreferences(
      codexCommand: "/usr/local/bin/codex",
      codexExtraArgs: "--api-mode enterprise",
      codexEnvironmentVariables: ["FOO": "bar", "BAZ": "qux"]
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(GeneralPreferences.self, from: data)

    XCTAssertEqual(decoded.codexCommand, "/usr/local/bin/codex")
    XCTAssertEqual(decoded.codexExtraArgs, "--api-mode enterprise")
    XCTAssertEqual(decoded.codexEnvironmentVariables, ["FOO": "bar", "BAZ": "qux"])
  }

  func testDefaultsAreEmptyWhenUnset() {
    let prefs = GeneralPreferences()
    XCTAssertEqual(prefs.claudeModel, "")
    XCTAssertEqual(prefs.claudeEffort, "")
    XCTAssertEqual(prefs.claudeAllowedTools, "")
    XCTAssertEqual(prefs.claudeDisallowedTools, "")
    XCTAssertEqual(prefs.codexCommand, "")
    XCTAssertEqual(prefs.codexExtraArgs, "")
    XCTAssertEqual(prefs.codexEnvironmentVariables, [:])
  }

  func testLegacyJSONWithoutNewKeysDecodesToDefaults() throws {
    // A preferences blob written before these fields existed must still decode.
    let legacyJSON = """
    {
      "autoApproveLowRisk": false,
      "claudeCommand": "claude",
      "claudePath": "",
      "chatProvider": "codex",
      "codexModel": "gpt-5.4",
      "defaultWorkingDirectory": "",
      "appendSystemPrompt": "",
      "systemPrompt": "",
      "showDetailedPermissionInfo": true,
      "permissionRequestTimeout": 3600,
      "permissionTimeoutEnabled": false,
      "maxConcurrentPermissionRequests": 5,
      "disallowedTools": []
    }
    """
    let data = Data(legacyJSON.utf8)
    let decoded = try JSONDecoder().decode(GeneralPreferences.self, from: data)

    XCTAssertEqual(decoded.codexCommand, "")
    XCTAssertEqual(decoded.codexExtraArgs, "")
    XCTAssertEqual(decoded.codexEnvironmentVariables, [:])
    XCTAssertEqual(decoded.claudeModel, "")
    XCTAssertEqual(decoded.claudeEffort, "")
    XCTAssertEqual(decoded.claudeAllowedTools, "")
    XCTAssertEqual(decoded.claudeDisallowedTools, "")
  }
}
