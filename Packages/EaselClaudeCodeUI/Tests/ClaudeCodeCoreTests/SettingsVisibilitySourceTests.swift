import Foundation
import XCTest

final class SettingsVisibilitySourceTests: XCTestCase {

  func testSessionSettingsDoNotExposeProviderPicker() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/SettingsView.swift")

    XCTAssertFalse(source.contains("Picker(\"Provider\""))
    XCTAssertFalse(source.contains("Text(\"Provider\")"))
    XCTAssertFalse(source.contains("Switching providers starts a fresh conversation."))
  }

  func testGlobalSettingsShowsProviderPickerAndProviderConfiguration() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/GlobalSettingsView.swift")

    XCTAssertTrue(source.contains("Picker(\"Provider\""))
    XCTAssertTrue(source.contains("codexConfigurationRow"))
    XCTAssertTrue(source.contains("claudeConfigurationRow"))
    XCTAssertTrue(source.contains("ClaudeModelPickerRow"))
    XCTAssertTrue(source.contains("Allowed Tools"))
    XCTAssertTrue(source.contains("Denied Tools"))
    XCTAssertFalse(source.contains("$preferences.claudeEffort"))
    XCTAssertFalse(source.contains("Switching providers starts a fresh conversation."))
    XCTAssertFalse(source.contains("Claude Code"))
  }

  func testGlobalSettingsDoesNotExposePromptDebugOrResetSections() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/GlobalSettingsView.swift")

    XCTAssertFalse(source.contains("Default Working Directory"))
    XCTAssertFalse(source.contains("New sessions will use this directory by default"))
    XCTAssertFalse(source.contains("Append System Prompt"))
    XCTAssertFalse(source.contains("Debug Information Not Available"))
    XCTAssertFalse(source.contains("Terminal Reproduction Command"))
    XCTAssertFalse(source.contains("Full Debug Report"))
    XCTAssertFalse(source.contains("Reset All Settings"))
  }

  func testMCPConfigurationVisibleCopyDoesNotNameClaudeConfigPath() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/MCPConfigurationView.swift")

    XCTAssertFalse(source.contains("Configuration is stored at ~/.config/claude"))
  }

  func testRuntimeErrorsDoNotPointAtRemovedClaudeSettings() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/ViewModels/ChatViewModel.swift")

    XCTAssertFalse(source.contains("Settings > Claude Command"))
    XCTAssertFalse(source.contains("Claude Not Installed"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
