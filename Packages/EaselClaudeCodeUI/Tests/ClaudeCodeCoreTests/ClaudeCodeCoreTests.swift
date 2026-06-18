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
    let didStartClaude = await waitUntilClaudeResumeStarts(client)
    XCTAssertTrue(didStartClaude)
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
  func testSwitchingAwayFromLoadingClaudeSessionKeepsTurnRunning() async throws {
    let storage = InMemorySessionStorage(sessions: [
      StoredSession(
        id: "session-a",
        createdAt: Date(),
        firstUserMessage: "A",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "A old")],
        workingDirectory: NSTemporaryDirectory(),
        provider: .claude
      ),
      StoredSession(
        id: "session-b",
        createdAt: Date(),
        firstUserMessage: "B",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "B old")],
        workingDirectory: NSTemporaryDirectory(),
        provider: .claude
      )
    ])
    let client = HangingClaudeCodeClient()
    let preferences = GlobalPreferencesStorage(
      persistentManager: PersistentPreferencesManager(
        applicationSupportURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("ClaudeSwitchLoadingTests-\(UUID().uuidString)", isDirectory: true)
      )
    )
    preferences.chatProvider = .claude
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: storage,
      settingsStorage: SettingsStorageManager(),
      globalPreferences: preferences,
      customPermissionService: MockCustomPermissionService()
    )

    await viewModel.resumeSession(id: "session-a")
    viewModel.setWorkingDirectory(NSTemporaryDirectory())
    viewModel.sendMessage("continue A")

    let didStartLoading = await waitUntilLoadingStarts(viewModel)
    XCTAssertTrue(didStartLoading)
    let didStartClaude = await waitUntilClaudeResumeStarts(client)
    XCTAssertTrue(didStartClaude)
    XCTAssertTrue(viewModel.isCurrentSessionLoading)

    await viewModel.switchToSession("session-b")

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertFalse(viewModel.isCurrentSessionLoading)
    XCTAssertEqual(viewModel.currentSessionId, "session-b")
    XCTAssertEqual(viewModel.messages.map(\.content), ["B old"])

    await viewModel.switchToSession("session-a")

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertTrue(viewModel.isCurrentSessionLoading)
    XCTAssertEqual(viewModel.currentSessionId, "session-a")
    XCTAssertTrue(viewModel.messages.contains { $0.content == "continue A" })

    viewModel.cancelRequest()
    client.finish()
  }

  @MainActor
  func testInjectingAnotherSessionKeepsLoadingClaudeTurnRunning() async throws {
    let workingDirectory = NSTemporaryDirectory()
    let storage = InMemorySessionStorage(sessions: [
      StoredSession(
        id: "session-a",
        createdAt: Date(),
        firstUserMessage: "A",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "A old")],
        workingDirectory: workingDirectory,
        provider: .claude
      ),
      StoredSession(
        id: "session-b",
        createdAt: Date(),
        firstUserMessage: "B",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "B old")],
        workingDirectory: workingDirectory,
        provider: .claude
      )
    ])
    let client = HangingClaudeCodeClient()
    let preferences = isolatedClaudePreferences()
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: storage,
      settingsStorage: SettingsStorageManager(),
      globalPreferences: preferences,
      customPermissionService: MockCustomPermissionService()
    )

    await viewModel.resumeSession(id: "session-a")
    viewModel.setWorkingDirectory(workingDirectory)
    viewModel.sendMessage("continue A")

    let didStartLoading = await waitUntilLoadingStarts(viewModel)
    XCTAssertTrue(didStartLoading)
    let didStartClaude = await waitUntilClaudeResumeStarts(client)
    XCTAssertTrue(didStartClaude)

    viewModel.injectSession(
      sessionId: "session-b",
      messages: [ChatMessage(role: .user, content: "B old")],
      workingDirectory: workingDirectory,
      provider: .claude
    )

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertFalse(viewModel.isCurrentSessionLoading)
    XCTAssertEqual(viewModel.currentSessionId, "session-b")
    XCTAssertEqual(viewModel.messages.map(\.content), ["B old"])

    viewModel.injectSession(
      sessionId: "session-a",
      messages: [ChatMessage(role: .user, content: "A old")],
      workingDirectory: workingDirectory,
      provider: .claude
    )

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertTrue(viewModel.isCurrentSessionLoading)
    XCTAssertEqual(viewModel.currentSessionId, "session-a")
    XCTAssertTrue(viewModel.messages.contains { $0.content == "continue A" })

    viewModel.cancelRequest()
    client.finish()
  }

  @MainActor
  func testStartingNewSessionKeepsLoadingClaudeTurnRunning() async throws {
    let workingDirectory = NSTemporaryDirectory()
    let storage = InMemorySessionStorage(sessions: [
      StoredSession(
        id: "session-a",
        createdAt: Date(),
        firstUserMessage: "A",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "A old")],
        workingDirectory: workingDirectory,
        provider: .claude
      )
    ])
    let client = HangingClaudeCodeClient()
    let preferences = isolatedClaudePreferences()
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: storage,
      settingsStorage: SettingsStorageManager(),
      globalPreferences: preferences,
      customPermissionService: MockCustomPermissionService()
    )

    await viewModel.resumeSession(id: "session-a")
    viewModel.setWorkingDirectory(workingDirectory)
    viewModel.sendMessage("continue A")

    let didStartLoading = await waitUntilLoadingStarts(viewModel)
    XCTAssertTrue(didStartLoading)
    let didStartClaude = await waitUntilClaudeResumeStarts(client)
    XCTAssertTrue(didStartClaude)

    viewModel.startNewSession(workingDirectory: workingDirectory)

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertFalse(viewModel.isCurrentSessionLoading)
    XCTAssertNil(viewModel.currentSessionId)
    XCTAssertTrue(viewModel.messages.isEmpty)
    XCTAssertEqual(viewModel.projectPath, workingDirectory)

    viewModel.injectSession(
      sessionId: "session-a",
      messages: [ChatMessage(role: .user, content: "A old")],
      workingDirectory: workingDirectory,
      provider: .claude
    )

    XCTAssertEqual(client.cancelCallCount, 0)
    XCTAssertTrue(viewModel.isLoading)
    XCTAssertTrue(viewModel.isCurrentSessionLoading)
    XCTAssertEqual(viewModel.currentSessionId, "session-a")
    XCTAssertTrue(viewModel.messages.contains { $0.content == "continue A" })

    viewModel.cancelRequest()
    client.finish()
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

  @MainActor
  private func waitUntilClaudeResumeStarts(_ client: HangingClaudeCodeClient) async -> Bool {
    for _ in 0..<20 {
      if client.resumeConversationCallCount > 0 {
        return true
      }

      try? await Task.sleep(for: .milliseconds(10))
    }

    return false
  }

  @MainActor
  private func isolatedClaudePreferences() -> GlobalPreferencesStorage {
    let preferences = GlobalPreferencesStorage(
      persistentManager: PersistentPreferencesManager(
        applicationSupportURL: FileManager.default.temporaryDirectory
          .appendingPathComponent("ClaudeSwitchLoadingTests-\(UUID().uuidString)", isDirectory: true)
      )
    )
    preferences.chatProvider = .claude
    return preferences
  }
}

private final class HangingClaudeCodeClient: ClaudeCode {
  var configuration = ClaudeCodeConfiguration.default
  var lastExecutedCommandInfo: ExecutedCommandInfo?
  private(set) var cancelCallCount = 0
  private(set) var resumeConversationCallCount = 0
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
    resumeConversationCallCount += 1
    return .stream(subject.eraseToAnyPublisher())
  }

  func listSessions() async throws -> [SessionInfo] {
    []
  }

  func cancel() {
    cancelCallCount += 1
  }

  func validateCommand(_ command: String) async throws -> Bool {
    true
  }

  func finish() {
    subject.send(completion: .finished)
  }
}

private actor InMemorySessionStorage: SessionStorageProtocol {
  private var sessions: [String: StoredSession]

  init(sessions: [StoredSession]) {
    self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
  }

  func saveSession(
    id: String,
    firstMessage: String,
    workingDirectory: String?,
    branchName: String?,
    isWorktree: Bool,
    provider: ChatProvider
  ) async throws {
    sessions[id] = StoredSession(
      id: id,
      createdAt: Date(),
      firstUserMessage: firstMessage,
      lastAccessedAt: Date(),
      workingDirectory: workingDirectory,
      branchName: branchName,
      isWorktree: isWorktree,
      provider: provider
    )
  }

  func getAllSessions() async throws -> [StoredSession] {
    sessions.values.sorted { $0.id < $1.id }
  }

  func getSession(id: String) async throws -> StoredSession? {
    sessions[id]
  }

  func updateLastAccessed(id: String) async throws {
    guard var session = sessions[id] else { return }
    session.lastAccessedAt = Date()
    sessions[id] = session
  }

  func deleteSession(id: String) async throws {
    sessions.removeValue(forKey: id)
  }

  func deleteAllSessions() async throws {
    sessions.removeAll()
  }

  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    guard var session = sessions[id] else { return }
    session.messages = messages
    sessions[id] = session
  }

  func updateSessionId(oldId: String, newId: String) async throws {
    guard var session = sessions.removeValue(forKey: oldId) else { return }
    session = StoredSession(
      id: newId,
      createdAt: session.createdAt,
      firstUserMessage: session.firstUserMessage,
      lastAccessedAt: session.lastAccessedAt,
      messages: session.messages,
      workingDirectory: session.workingDirectory,
      branchName: session.branchName,
      isWorktree: session.isWorktree,
      provider: session.provider,
      usageSummary: session.usageSummary
    )
    sessions[newId] = session
  }
}
