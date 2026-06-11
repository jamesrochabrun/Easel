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
