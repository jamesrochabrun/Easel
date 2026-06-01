import XCTest
@testable import ClaudeCodeCore

final class CodexMessageMapperTests: XCTestCase {

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
