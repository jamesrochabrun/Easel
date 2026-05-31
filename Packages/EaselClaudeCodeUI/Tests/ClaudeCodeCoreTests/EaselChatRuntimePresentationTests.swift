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

    XCTAssertEqual(presentation.title, "Reading package.json")
    XCTAssertEqual(presentation.status, .completed)
    XCTAssertEqual(presentation.metadata, "File review - 3 lines - Done")
    XCTAssertNil(presentation.preview)
  }

  func testToolPresentationMapsRunningBashCommandToFriendlyActivity() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "npm run dev"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Starting preview")
    XCTAssertEqual(presentation.status, .running)
    XCTAssertEqual(presentation.metadata, "Preview - Working")
    XCTAssertEqual(presentation.statusLabel, "Working")
    XCTAssertNil(presentation.preview)
  }

  func testToolPresentationSummarizesWriteWithoutRawContentPreview() {
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

    XCTAssertEqual(presentation.title, "Updating main.ts")
    XCTAssertEqual(presentation.metadata, "File update - Working")
    XCTAssertNil(presentation.preview)
  }

  func testToolPresentationDoesNotExposeComplexBashCommand() {
    let command = "cd /private/tmp/example && xcodebuild -workspace SecretApp.xcworkspace -scheme SecretApp test"
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": command])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Checking tests")
    XCTAssertEqual(presentation.metadata, "Quality check - Working")
    XCTAssertFalse(presentation.title.contains("xcodebuild"))
    XCTAssertFalse(presentation.metadata.contains("SecretApp"))
    XCTAssertNil(presentation.preview)
  }

  func testFileChangePresentationHidesFullPathInMetadata() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "FileChange",
      toolInputData: ToolInputData(parameters: ["file_path": "/private/tmp/example/Sources/SecretView.swift"])
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "Changed /private/tmp/example/Sources/SecretView.swift",
      messageType: .toolResult,
      toolName: "FileChange"
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: toolResult)

    XCTAssertEqual(presentation.title, "Updating SecretView.swift")
    XCTAssertEqual(presentation.metadata, "File update - Done")
    XCTAssertFalse(presentation.metadata.contains("/private/tmp"))
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

  func testActiveActivityTitleFindsUnfinishedToolUse() {
    let userMessage = ChatMessage(role: .user, content: "Check the app")
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "swift test"])
    )

    let title = EaselToolCardPresentation.activeActivityTitle(in: [userMessage, toolUse])

    XCTAssertEqual(title, "Checking tests")
  }

  func testActiveActivityTitleIgnoresCompletedToolUse() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "swift test"])
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "exit 0",
      messageType: .toolResult,
      toolName: "Bash"
    )

    let title = EaselToolCardPresentation.activeActivityTitle(in: [toolUse, toolResult])

    XCTAssertNil(title)
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
