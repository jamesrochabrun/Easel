//
//  CodexUserConfigCompatibilityTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class CodexUserConfigCompatibilityTests: XCTestCase {
  func testDetectsUnsupportedTopLevelReasoningEffort() {
    let config = """
    model = "gpt-5.5"
    model_reasoning_effort = "xhigh"
    """

    XCTAssertTrue(CodexUserConfigCompatibility.containsUnsupportedReasoningEffort(config))
  }

  func testDetectsUnsupportedProfileReasoningEffort() {
    let config = """
    [profiles.auto]
    sandbox = "workspace-write"
    model_reasoning_effort = "xhigh"
    """

    XCTAssertTrue(CodexUserConfigCompatibility.containsUnsupportedReasoningEffort(config))
  }

  func testAllowsSupportedReasoningEfforts() {
    let config = """
    model_reasoning_effort = "high"
    plan_mode_reasoning_effort = "medium"
    """

    XCTAssertFalse(CodexUserConfigCompatibility.containsUnsupportedReasoningEffort(config))
  }

  func testConfigOverridesUseCodexSupportedReasoningEffort() throws {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let codexDirectory = homeDirectory.appendingPathComponent(".codex")
    try FileManager.default.createDirectory(
      at: codexDirectory,
      withIntermediateDirectories: true
    )
    try """
    model_reasoning_effort = "xhigh"
    plan_mode_reasoning_effort = "xhigh"
    """.write(
      to: codexDirectory.appendingPathComponent("config.toml"),
      atomically: true,
      encoding: .utf8
    )

    let overrides = CodexUserConfigCompatibility.compatibleConfigOverrides(
      homeDirectory: homeDirectory.path
    )

    XCTAssertEqual(overrides["model_reasoning_effort"], "\"high\"")
    XCTAssertEqual(overrides["plan_mode_reasoning_effort"], "\"high\"")
  }

  func testConfigOverridesAddMissingTUIDisableMouseCapture() throws {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let codexDirectory = homeDirectory.appendingPathComponent(".codex")
    try FileManager.default.createDirectory(
      at: codexDirectory,
      withIntermediateDirectories: true
    )
    try """
    [tui.model_availability_nux]
    "gpt-5.5" = 4
    """.write(
      to: codexDirectory.appendingPathComponent("config.toml"),
      atomically: true,
      encoding: .utf8
    )

    let overrides = CodexUserConfigCompatibility.compatibleConfigOverrides(
      homeDirectory: homeDirectory.path
    )

    XCTAssertEqual(overrides["tui.disable_mouse_capture"], "false")
  }

  func testConfigOverridesDoNotReplaceExplicitTUIDisableMouseCapture() throws {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let codexDirectory = homeDirectory.appendingPathComponent(".codex")
    try FileManager.default.createDirectory(
      at: codexDirectory,
      withIntermediateDirectories: true
    )
    try """
    [tui]
    disable_mouse_capture = true

    [tui.model_availability_nux]
    "gpt-5.5" = 4
    """.write(
      to: codexDirectory.appendingPathComponent("config.toml"),
      atomically: true,
      encoding: .utf8
    )

    let overrides = CodexUserConfigCompatibility.compatibleConfigOverrides(
      homeDirectory: homeDirectory.path
    )

    XCTAssertNil(overrides["tui.disable_mouse_capture"])
  }
}
