import XCTest
@testable import ClaudeCodeCore

@MainActor
final class EaselChatRuntimePresentationTests: XCTestCase {

  func testToolPresentationMapsCompletedReadResult() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Read",
      toolInputData: ToolInputData(parameters: ["file_path": "/tmp/package.json"])
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "{\n  \"name\": \"easel\"\n}",
      messageType: .toolResult,
      toolName: "Read"
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: toolResult)

    XCTAssertEqual(presentation.title, "Read package.json")
    XCTAssertEqual(presentation.status, .completed)
    XCTAssertEqual(presentation.metadata, "File - 3 lines")
    XCTAssertEqual(presentation.preview, "{\n  \"name\": \"easel\"\n}")
  }

  func testToolPresentationMapsRunningBashCommand() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "npm run dev"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "npm run dev")
    XCTAssertEqual(presentation.status, .running)
    XCTAssertEqual(presentation.metadata, "Bash - running")
  }

  func testToolPresentationUsesWriteInputForPreviewWhenResultIsEmpty() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Write",
      toolInputData: ToolInputData(
        parameters: ["file_path": "/tmp/main.ts", "content": "let name = \"easel\"\nconsole.log(name)"],
        rawParameters: ["file_path": "/tmp/main.ts", "content": "let name = \"easel\"\nconsole.log(name)"]
      )
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Write /tmp/main.ts")
    XCTAssertEqual(presentation.preview, "let name = \"easel\"\nconsole.log(name)")
  }

  func testToolPresentationMapsFailedAndDeniedStates() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash"
    )

    let failed = EaselToolCardPresentation(
      toolUse: toolUse,
      toolResult: ChatMessage(role: .toolError, content: "nope", messageType: .toolError, toolName: "Bash")
    )
    let denied = EaselToolCardPresentation(
      toolUse: toolUse,
      toolResult: ChatMessage(role: .toolDenied, content: "denied", messageType: .toolDenied, toolName: "Bash")
    )

    XCTAssertEqual(failed.status, .failed)
    XCTAssertEqual(denied.status, .denied)
  }

  func testToolPresentationExtractsLocalhostURL() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "npm run dev"])
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "Local: http://localhost:4325/AgentHubPage",
      messageType: .toolResult,
      toolName: "Bash"
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: toolResult)

    XCTAssertEqual(presentation.localhostURL?.absoluteString, "http://localhost:4325/AgentHubPage")
    XCTAssertNil(presentation.preview)
  }

  func testRelativeMessageTimeFormatting() {
    let formatter = RelativeMessageTimeFormatter()
    let now = Date(timeIntervalSince1970: 1_000)

    XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 995), now: now), "now")
    XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 970), now: now), "30 sec ago")
    XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 880), now: now), "2 min ago")
    XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 1_000 - 7_200), now: now), "2 hr ago")
  }
}
