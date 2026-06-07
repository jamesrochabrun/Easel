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
    XCTAssertEqual(presentation.subtitle, "3 lines")
    XCTAssertNil(presentation.preview)
  }

  func testReadSkillManifestTitleIncludesSkillName() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Read",
      toolInputData: ToolInputData(parameters: ["file_path": "/Users/test/.codex/skills/swiftui-pro/SKILL.md"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Reading swiftui-pro skill")
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

    XCTAssertEqual(presentation.title, "Starting the preview")
    XCTAssertEqual(presentation.status, .running)
    // The raw command is never shown — only the action.
    XCTAssertNil(presentation.subtitle)
    XCTAssertEqual(presentation.statusLabel, "Working")
    XCTAssertNil(presentation.preview)
  }

  func testBashTitleUsesFriendlyVerbAndNeverShowsTheCommand() {
    let cases: [(command: String, title: String)] = [
      ("git status", "Checking project history"),
      ("ls", "Looking through files"),
      ("cat package.json", "Reading package.json"),
      ("sed -n '1,260p' index.html", "Reading index.html"),
      ("sed -n '1,140p' /Users/test/.codex/skills/swiftui-pro/SKILL.md", "Reading swiftui-pro skill"),
      ("find resources -maxdepth 2 -type f -print", "Looking through resources"),
      ("pwd && rg --files -g '!*node_modules*' -g '!*.png'", "Searching files"),
      ("cp src/a.txt dist/a.txt", "Copying files"),
      ("curl http://127.0.0.1:4173/", "Checking for updates"),
      ("curl http://localhost:3000/", "Checking for updates"),
      ("curl https://example.com", "Fetching from the web"),
    ]

    for testCase in cases {
      let toolUse = ChatMessage(
        role: .assistant,
        content: "",
        messageType: .toolUse,
        toolName: "Bash",
        toolInputData: ToolInputData(parameters: ["command": testCase.command])
      )

      let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

      XCTAssertEqual(presentation.title, testCase.title, "command: \(testCase.command)")
      // Only the action is shown; the raw command never appears.
      XCTAssertNil(presentation.subtitle, "command: \(testCase.command)")
    }
  }

  func testBashTitleHandlesComplexCommandsWithoutLeakingParseArtifacts() {
    let cases: [(command: String, title: String)] = [
      // Inline Python verification scripts must not grab a word from the heredoc body
      // (previously produced "Running from").
      ("python3 - <<'PY'\nfrom pathlib import Path\nprint('ok')\nPY", "Running a script"),
      ("python3 -c \"print(1)\"", "Running a script"),
      // A quoted program token must be unwrapped (previously produced "Running 'find").
      ("'find resources -type f -print'", "Looking through resources"),
      // `file` is a real program but read better as inspection than "Running file".
      ("file \"$HOME/.codex/x/_image_id_.png\"", "Inspecting _image_id_.png"),
    ]

    for testCase in cases {
      let toolUse = ChatMessage(
        role: .assistant,
        content: "",
        messageType: .toolUse,
        toolName: "Bash",
        toolInputData: ToolInputData(parameters: ["command": testCase.command])
      )

      let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

      XCTAssertEqual(presentation.title, testCase.title, "command: \(testCase.command)")
      XCTAssertFalse(presentation.title.contains("from"), "command: \(testCase.command)")
      XCTAssertFalse(presentation.title.contains("'"), "command: \(testCase.command)")
    }
  }

  func testBashTitleDescribesCodexGeneratedImageHandlingWithoutLeakingInternals() {
    let cases: [(command: String, title: String)] = [
      // Locating the generated image inside Codex's private home (was "Looking through .codex").
      ("find \"$HOME/.codex\" -path '*generated_images*' -type f -mmin -10 -print", "Locating the generated image"),
      // Inspecting the opaque temp file (was "Inspecting ig_0f31a90af…").
      ("file /Users/test/.codex/generated_images/019e/ig_0f31a90af2b6ed46.png", "Checking the generated image"),
      // Copying it into the project should read as saving the image, not "Copying files".
      ("cp /Users/test/.codex/generated_images/019e/ig_abc.png resources/hero.png", "Saving the generated image"),
    ]

    for testCase in cases {
      let toolUse = ChatMessage(
        role: .assistant,
        content: "",
        messageType: .toolUse,
        toolName: "Bash",
        toolInputData: ToolInputData(parameters: ["command": testCase.command])
      )

      let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

      XCTAssertEqual(presentation.title, testCase.title, "command: \(testCase.command)")
      XCTAssertFalse(presentation.title.contains(".codex"), "command: \(testCase.command)")
      XCTAssertFalse(presentation.title.contains("ig_"), "command: \(testCase.command)")
    }
  }

  func testEmptyCodexCommandIsNotDisplayable() {
    // No-op executions (empty script) must be filtered out, not shown as "Running a command".
    XCTAssertFalse(CodexMessageMapper.isDisplayableCommand("/bin/zsh -lc ''"))
    XCTAssertFalse(CodexMessageMapper.isDisplayableCommand("   "))
    XCTAssertTrue(CodexMessageMapper.isDisplayableCommand("/bin/zsh -lc 'echo hello'"))
  }

  func testBashPresentationNeverFallsBackToRunningACommand() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash"
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Checking the project")
    XCTAssertFalse(presentation.title.contains("Running a command"))
  }

  func testBashTitleDoesNotFalsePositiveOnSubstrings() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "cat information.txt"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    // "information" contains "format" but must not be read as a formatting command.
    XCTAssertEqual(presentation.title, "Reading information.txt")
  }

  func testGrepPresentationSurfacesSearchPattern() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Grep",
      toolInputData: ToolInputData(parameters: ["pattern": "useState", "include": "*.swift"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Searching for \"useState\"")
    XCTAssertEqual(presentation.subtitle, "in *.swift")
  }

  func testWebSearchPresentationDoesNotShowPlaceholderQuery() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "WebSearch",
      toolInputData: ToolInputData(parameters: ["query": " Search "])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Searching the web")
  }

  func testWebSearchPresentationShowsRealQuery() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "WebSearch",
      toolInputData: ToolInputData(parameters: ["query": "design system examples"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Searching the web for \"design system examples\"")
  }

  func testGlobPresentationDescribesFileType() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Glob",
      toolInputData: ToolInputData(parameters: ["pattern": "**/*.swift"])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    XCTAssertEqual(presentation.title, "Finding Swift files")
    XCTAssertNil(presentation.subtitle)
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

    XCTAssertEqual(presentation.title, "Creating main.ts")
    XCTAssertNil(presentation.subtitle)
    XCTAssertNil(presentation.preview)
  }

  func testToolPresentationShowsFriendlyVerbWithRealCommand() {
    let command = "cd /private/tmp/example && xcodebuild -workspace SecretApp.xcworkspace -scheme SecretApp test"
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": command])
    )

    let presentation = EaselToolCardPresentation(toolUse: toolUse, toolResult: nil)

    // Friendly verb only — the raw command (and any paths it contains) is never shown.
    XCTAssertEqual(presentation.title, "Running tests")
    XCTAssertNil(presentation.subtitle)
    XCTAssertFalse(presentation.title.contains("xcodebuild"))
    XCTAssertFalse(presentation.title.contains("/private/tmp"))
    XCTAssertNil(presentation.preview)
  }

  func testFileChangePresentationKeepsFriendlyTitle() {
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
    XCTAssertFalse(presentation.title.contains("/private/tmp"))
    XCTAssertFalse(presentation.subtitle?.contains("/private/tmp") ?? false)
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

    XCTAssertEqual(title, "Running tests")
  }

  func testActiveActivityTitleIgnoresCompletedToolUse() {
    let toolUse = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "swift test"]),
      toolUseID: "test-1"
    )
    let toolResult = ChatMessage(
      role: .toolResult,
      content: "exit 0",
      messageType: .toolResult,
      toolName: "Bash",
      toolUseID: "test-1"
    )

    let title = EaselToolCardPresentation.activeActivityTitle(in: [toolUse, toolResult])

    XCTAssertNil(title)
  }

  func testActiveActivityTitleUsesToolIDsForInterleavedResults() {
    let firstTool = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "swift test"]),
      toolUseID: "first"
    )
    let secondTool = ChatMessage(
      role: .assistant,
      content: "",
      messageType: .toolUse,
      toolName: "Bash",
      toolInputData: ToolInputData(parameters: ["command": "git status"]),
      toolUseID: "second"
    )
    let secondResult = ChatMessage(
      role: .toolResult,
      content: "exit 0",
      messageType: .toolResult,
      toolName: "Bash",
      toolUseID: "second"
    )

    let title = EaselToolCardPresentation.activeActivityTitle(in: [firstTool, secondTool, secondResult])

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
