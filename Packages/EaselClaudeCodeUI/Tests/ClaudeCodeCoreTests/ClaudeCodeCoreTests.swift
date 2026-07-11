import XCTest
import Combine
import ClaudeCodeSDK
import CCCustomPermissionServiceInterface
@testable import ClaudeCodeCore

final class ClaudeCodeCoreTests: XCTestCase {
  
  func testExample() {
    // Placeholder test
    XCTAssertTrue(true)
  }

  @MainActor
  func testRuntimeHiddenContextProviderIsIncludedInAPIContent() {
    let viewModel = ChatViewModel(
      claudeClient: HangingClaudeCodeClient(),
      sessionStorage: NoOpSessionStorage(),
      settingsStorage: SettingsStorageManager(),
      globalPreferences: GlobalPreferencesStorage(),
      customPermissionService: MockCustomPermissionService(),
      shouldManageSessions: false
    )
    viewModel.runtimeHiddenContextProvider = {
      "Runtime project context"
    }

    let content = viewModel.makeAPIContent(
      text: "hello",
      context: "Visible context",
      hiddenContext: "Caller hidden context"
    )

    XCTAssertTrue(content.contains("hello"))
    XCTAssertTrue(content.contains("--- Context ---\nVisible context"))
    XCTAssertTrue(content.contains("Caller hidden context"))
    XCTAssertTrue(content.contains("Runtime project context"))
  }

  @MainActor
  func testEphemeralProviderDoesNotChangePersistedDefault() {
    let preferences = GlobalPreferencesStorage()
    preferences.chatProvider = .codex
    let viewModel = ChatViewModel(
      claudeClient: HangingClaudeCodeClient(),
      sessionStorage: NoOpSessionStorage(),
      settingsStorage: SettingsStorageManager(),
      globalPreferences: preferences,
      customPermissionService: MockCustomPermissionService(),
      shouldManageSessions: false
    )

    viewModel.configureEphemeralProvider(.claude)

    XCTAssertEqual(viewModel.activeProvider, .claude)
    XCTAssertEqual(preferences.chatProvider, .codex)
  }

  @MainActor
  func testRuntimeHiddenContextCanBeExcludedFromAPIContent() {
    let viewModel = ChatViewModel(
      claudeClient: HangingClaudeCodeClient(),
      sessionStorage: NoOpSessionStorage(),
      settingsStorage: SettingsStorageManager(),
      globalPreferences: GlobalPreferencesStorage(),
      customPermissionService: MockCustomPermissionService(),
      shouldManageSessions: false
    )
    viewModel.runtimeHiddenContextProvider = {
      "Runtime project context"
    }

    let content = viewModel.makeAPIContent(
      text: "ok",
      hiddenContext: "Caller hidden context",
      includeRuntimeHiddenContext: false
    )

    XCTAssertTrue(content.contains("ok"))
    XCTAssertTrue(content.contains("Caller hidden context"))
    XCTAssertFalse(content.contains("Runtime project context"))
  }

  @MainActor
  func testOutgoingHiddenContextReplacesRuntimeContextForCodexFollowUps() {
    let preferences = GlobalPreferencesStorage()
    preferences.chatProvider = .codex
    let viewModel = ChatViewModel(
      claudeClient: HangingClaudeCodeClient(),
      sessionStorage: NoOpSessionStorage(),
      settingsStorage: SettingsStorageManager(),
      globalPreferences: preferences,
      customPermissionService: MockCustomPermissionService(),
      shouldManageSessions: false
    )
    var runtimeCallCount = 0
    var outgoingCallCount = 0
    viewModel.runtimeHiddenContextProvider = {
      runtimeCallCount += 1
      return "Runtime project context"
    }
    viewModel.outgoingHiddenContextProvider = {
      outgoingCallCount += 1
      return "Resource delta context"
    }

    let initialContent = viewModel.makeOutgoingAPIContent(text: "hello")

    XCTAssertTrue(initialContent.contains("Runtime project context"))
    XCTAssertFalse(initialContent.contains("Resource delta context"))
    XCTAssertEqual(runtimeCallCount, 1)
    XCTAssertEqual(outgoingCallCount, 0)

    viewModel.injectSession(
      sessionId: "session-a",
      messages: [],
      workingDirectory: NSTemporaryDirectory()
    )

    let followUpContent = viewModel.makeOutgoingAPIContent(text: "again")

    XCTAssertFalse(followUpContent.contains("Runtime project context"))
    XCTAssertTrue(followUpContent.contains("Resource delta context"))
    XCTAssertEqual(runtimeCallCount, 1)
    XCTAssertEqual(outgoingCallCount, 1)
  }

  @MainActor
  func testLoadingIndicatorIsScopedToActiveSession() async throws {
    let client = HangingClaudeCodeClient()
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: NoOpSessionStorage(),
      settingsStorage: SettingsStorageManager(),
      globalPreferences: GlobalPreferencesStorage(),
      customPermissionService: MockCustomPermissionService(),
      shouldManageSessions: false
    )
    viewModel.injectSession(
      sessionId: "session-a",
      messages: [],
      workingDirectory: NSTemporaryDirectory()
    )

    let task = Task {
      await viewModel.resumeAfterApprovalTimeout(approved: true, toolName: "Edit")
    }

    let didStartLoading = await waitUntilLoadingStarts(viewModel)
    XCTAssertTrue(didStartLoading)
    XCTAssertTrue(viewModel.isCurrentSessionLoading)

    viewModel.injectSession(
      sessionId: "session-b",
      messages: [],
      workingDirectory: NSTemporaryDirectory()
    )

    XCTAssertTrue(viewModel.isLoading)
    XCTAssertFalse(viewModel.isCurrentSessionLoading)

    viewModel.injectSession(
      sessionId: "session-a",
      messages: [],
      workingDirectory: NSTemporaryDirectory()
    )

    XCTAssertTrue(viewModel.isCurrentSessionLoading)

    viewModel.cancelRequest()
    task.cancel()
    client.finish()
    await task.value
  }

  @MainActor
  private func waitUntilLoadingStarts(_ viewModel: ChatViewModel) async -> Bool {
    for _ in 0..<20 {
      if viewModel.isLoading {
        return true
      }

      try? await Task.sleep(for: .milliseconds(10))
    }

    return false
  }
}

private final class HangingClaudeCodeClient: ClaudeCode {
  var configuration = ClaudeCodeConfiguration.default
  var lastExecutedCommandInfo: ExecutedCommandInfo?
  private let subject = PassthroughSubject<ResponseChunk, Error>()

  func runWithStdin(
    stdinContent: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    .stream(subject.eraseToAnyPublisher())
  }

  func runSinglePrompt(
    prompt: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    .stream(subject.eraseToAnyPublisher())
  }

  func continueConversation(
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    .stream(subject.eraseToAnyPublisher())
  }

  func resumeConversation(
    sessionId: String,
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    .stream(subject.eraseToAnyPublisher())
  }

  func listSessions() async throws -> [SessionInfo] {
    []
  }

  func cancel() {}

  func validateCommand(_ command: String) async throws -> Bool {
    true
  }

  func finish() {
    subject.send(completion: .finished)
  }
}
