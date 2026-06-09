import XCTest
import CodexSDK
@testable import ClaudeCodeCore

final class CodexMessageMapperTests: XCTestCase {

  private func todos(_ json: String) throws -> [CodexTodoItem] {
    try JSONDecoder().decode([CodexTodoItem].self, from: Data(json.utf8))
  }

  func testTodoToolUseRendersCheckboxChecklistWithRealText() throws {
    let items = try todos("""
    [
      { "text": "Draft the outline", "completed": true },
      { "text": "Write slide two", "completed": false }
    ]
    """)

    let message = try XCTUnwrap(CodexMessageMapper.todoToolUse(items: items, itemID: "todo-1"))

    XCTAssertEqual(message.messageType, .toolUse)
    XCTAssertEqual(message.toolName, "TodoWrite")
    XCTAssertEqual(message.toolUseID, "todo-1")

    let todosParam = try XCTUnwrap(message.toolInputData?.parameters["todos"])
    XCTAssertTrue(todosParam.contains("- [x] Draft the outline"))
    XCTAssertTrue(todosParam.contains("- [ ] Write slide two"))
    // Real text replaces the old "[pending] Todo" placeholder, and raw status
    // tags never leak into the checklist.
    XCTAssertFalse(todosParam.contains("[pending]"))
    XCTAssertFalse(todosParam.contains("Todo\n"))
  }

  func testTodoToolResultResolvesCardWithProgressSummary() throws {
    let items = try todos("""
    [
      { "text": "A", "completed": true },
      { "text": "B", "completed": false }
    ]
    """)

    let result = try XCTUnwrap(CodexMessageMapper.todoToolResult(items: items, itemID: "todo-1"))

    // A paired result settles the card so it stops showing a perpetual "Working" spinner.
    XCTAssertEqual(result.messageType, .toolResult)
    XCTAssertEqual(result.toolName, "TodoWrite")
    XCTAssertEqual(result.toolUseID, "todo-1")
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.content.contains("1/2"))
  }

  func testTodoMappersReturnNilWhenNoItems() {
    XCTAssertNil(CodexMessageMapper.todoToolUse(items: [], itemID: "x"))
    XCTAssertNil(CodexMessageMapper.todoToolResult(items: nil, itemID: "x"))
  }

  func testCommandToolUseMapsToExistingToolCardShape() {
    let message = CodexMessageMapper.commandToolUse(command: "/bin/zsh -lc 'swift test'", itemID: "item-1")

    XCTAssertEqual(message.messageType, .toolUse)
    XCTAssertEqual(message.toolName, "Bash")
    XCTAssertEqual(message.toolInputData?.parameters["command"], "swift test")
    XCTAssertEqual(message.toolUseID, "item-1")
  }

  func testFailedCommandResultMapsToToolError() {
    let message = CodexMessageMapper.commandToolResult(output: "build failed", exitCode: 1, itemID: "item-1")

    XCTAssertEqual(message.role, .toolError)
    XCTAssertEqual(message.messageType, .toolError)
    XCTAssertEqual(message.toolName, "Bash")
    XCTAssertEqual(message.toolUseID, "item-1")
    XCTAssertTrue(message.isError)
    XCTAssertTrue(message.content.contains("exit 1"))
  }

  func testMCPToolUseFallsBackToGenericName() {
    let message = CodexMessageMapper.mcpToolUse(toolName: nil, arguments: nil, itemID: nil)

    XCTAssertEqual(message.messageType, .toolUse)
    XCTAssertEqual(message.toolName, "MCPTool")
  }

  func testShortenCommandHandlesCommonShellWrappers() {
    XCTAssertEqual(CodexMessageMapper.shortenCommand("/bin/bash -lc 'npm test'"), "npm test")
    XCTAssertEqual(CodexMessageMapper.shortenCommand("sh -lc \"ls\""), "ls")
  }
}
