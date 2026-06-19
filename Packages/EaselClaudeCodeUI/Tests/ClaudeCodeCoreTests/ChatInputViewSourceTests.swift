import Foundation
import XCTest

final class ChatInputViewSourceTests: XCTestCase {

  func testTextEditorUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains(".tint(EaselChatRuntimeStyle.inputTint(for: colorScheme))"))
  }

  func testPermissionModePickerIsHiddenForEmbeddedChat() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains("if viewModel.activeProvider == .codex"))
    XCTAssertTrue(source.contains("ClaudeModelBadge(modelIdentifier: globalPreferences.claudeModel)"))
    XCTAssertFalse(source.contains("if viewModel.activeProvider != .codex"))
    XCTAssertFalse(source.contains("PermissionModeButton(mode: $viewModel.permissionMode)"))
  }

  func testPermissionModeShortcutIsDisabledForEmbeddedChat() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatScreen.swift")

    XCTAssertFalse(source.contains("viewModel.permissionMode = newMode"))
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
