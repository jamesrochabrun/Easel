import XCTest
@testable import ClaudeCodeCore

final class CodexMessageMapperTests: XCTestCase {

  func testCommandToolUseMapsToExistingToolCardShape() {
    let message = CodexMessageMapper.commandToolUse(command: "/bin/zsh -lc 'swift test'")

    XCTAssertEqual(message.messageType, .toolUse)
    XCTAssertEqual(message.toolName, "Bash")
    XCTAssertEqual(message.toolInputData?.parameters["command"], "swift test")
  }

  func testFailedCommandResultMapsToToolError() {
    let message = CodexMessageMapper.commandToolResult(output: "build failed", exitCode: 1)

    XCTAssertEqual(message.role, .toolError)
    XCTAssertEqual(message.messageType, .toolError)
    XCTAssertEqual(message.toolName, "Bash")
    XCTAssertTrue(message.isError)
    XCTAssertTrue(message.content.contains("exit 1"))
  }

  func testMCPToolUseFallsBackToGenericName() {
    let message = CodexMessageMapper.mcpToolUse(toolName: nil, arguments: nil)

    XCTAssertEqual(message.messageType, .toolUse)
    XCTAssertEqual(message.toolName, "MCPTool")
  }
}
