import Foundation
import XCTest

final class ChatInputViewSourceTests: XCTestCase {

  func testTextEditorUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains(".tint(EaselChatRuntimeStyle.inputTint(for: colorScheme))"))
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
