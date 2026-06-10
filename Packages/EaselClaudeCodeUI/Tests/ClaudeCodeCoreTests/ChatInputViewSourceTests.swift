import Foundation
import XCTest

final class ChatInputViewSourceTests: XCTestCase {

  func testTextEditorUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains(".tint(EaselChatRuntimeStyle.inputTint(for: colorScheme))"))
  }

  func testPermissionModePickerIsHiddenForCodexProvider() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains("if viewModel.activeProvider == .codex"))
    XCTAssertTrue(source.contains("if viewModel.activeProvider != .codex"))
    XCTAssertTrue(source.contains("PermissionModeButton(mode: $viewModel.permissionMode)"))
  }

  func testPermissionModeShortcutIsDisabledForCodexProvider() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatScreen.swift")

    XCTAssertTrue(source.contains("if viewModel.activeProvider != .codex,"))
    XCTAssertTrue(source.contains("viewModel.permissionMode = newMode"))
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
