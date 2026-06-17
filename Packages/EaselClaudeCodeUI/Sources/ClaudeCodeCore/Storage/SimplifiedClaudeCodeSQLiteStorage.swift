import Foundation
import SQLite

// MARK: - SimplifiedClaudeCodeSQLiteStorage

/// Simple SQLite storage for Claude Code sessions using SQLite.swift without macros
/// Completely independent from Claude Code sessions
public actor SimplifiedClaudeCodeSQLiteStorage: SessionStorageProtocol {

  private var migrationManager: SimplifiedClaudeCodeSQLiteMigrationManager?
  private let applicationSupportDirectory: URL?

  public init(applicationSupportDirectory: URL? = nil) {
    self.applicationSupportDirectory = applicationSupportDirectory
  }

  public func saveSession(id: String, firstMessage: String, workingDirectory: String?, branchName: String?, isWorktree: Bool) async throws {
    try await initializeDatabaseIfNeeded()

    let insert = sessionsTable.insert(
      sessionIdColumn <- id,
      createdAtColumn <- Date(),
      firstUserMessageColumn <- firstMessage,
      lastAccessedAtColumn <- Date(),
      workingDirectoryColumn <- workingDirectory,
      branchNameColumn <- branchName,
      isWorktreeColumn <- isWorktree
    )

    try database.run(insert)
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    try await initializeDatabaseIfNeeded()

    var storedSessions = [StoredSession]()
    
    for sessionRow in try database.prepare(sessionsTable.order(lastAccessedAtColumn.desc)) {
      let sessionId = sessionRow[sessionIdColumn]
      
      // Load messages for this session
      let messages = try await getMessagesForSession(sessionId: sessionId)
      
      let storedSession = StoredSession(
        id: sessionId,
        createdAt: sessionRow[createdAtColumn],
        firstUserMessage: sessionRow[firstUserMessageColumn],
        lastAccessedAt: sessionRow[lastAccessedAtColumn],
        messages: messages,
        workingDirectory: sessionRow[workingDirectoryColumn],
        branchName: sessionRow[branchNameColumn],
        isWorktree: sessionRow[isWorktreeColumn],
        usageSummary: usageSummary(from: sessionRow)
      )
      
      storedSessions.append(storedSession)
    }
    return storedSessions
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    try await initializeDatabaseIfNeeded()
    
    guard let sessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == id)) else {
      return nil
    }
    
    // Load messages for this session
    let messages = try await getMessagesForSession(sessionId: id)
    
    let storedSession = StoredSession(
      id: sessionRow[sessionIdColumn],
      createdAt: sessionRow[createdAtColumn],
      firstUserMessage: sessionRow[firstUserMessageColumn],
      lastAccessedAt: sessionRow[lastAccessedAtColumn],
      messages: messages,
      workingDirectory: sessionRow[workingDirectoryColumn],
      branchName: sessionRow[branchNameColumn],
      isWorktree: sessionRow[isWorktreeColumn],
      usageSummary: usageSummary(from: sessionRow)
    )
    return storedSession
  }
  
  public func updateLastAccessed(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    let session = sessionsTable.filter(sessionIdColumn == id)
    let update = session.update(lastAccessedAtColumn <- Date())
    try database.run(update)
  }
  
  public func deleteSession(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete session (foreign key constraints will cascade to messages and attachments)
    let deleteSession = sessionsTable.filter(sessionIdColumn == id)
    try database.run(deleteSession.delete())
  }
  
  public func deleteAllSessions() async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete all sessions (foreign key constraints will cascade to messages and attachments)
    try database.run(sessionsTable.delete())
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    try await initializeDatabaseIfNeeded()

    try database.transaction {
      let existingMessages = messagesTable.filter(messageSessionIdColumn == id)
      try database.run(existingMessages.delete())

      // Insert new messages
      for (_, message) in messages.enumerated() {
        let insertMessage = messagesTable.insert(
          messageIdColumn <- message.id.uuidString,
          messageSessionIdColumn <- id,
          messageContentColumn <- message.content,
          messageRoleColumn <- message.role.rawValue,
          messageTimestampColumn <- message.timestamp,
          messageTypeColumn <- message.messageType.rawValue,
          messageToolNameColumn <- message.toolName,
          messageToolUseIdColumn <- message.toolUseID,
          messageToolInputDataColumn <- try? JSONEncoder().encode(message.toolInputData).base64EncodedString(),
          messageIsErrorColumn <- message.isError,
          messageIsCompleteColumn <- message.isComplete,
          messageWasCancelledColumn <- message.wasCancelled,
          messageTaskGroupIdColumn <- message.taskGroupId?.uuidString,
          messageIsTaskContainerColumn <- message.isTaskContainer,
        )

        try database.run(insertMessage)

        // Insert attachments if any
        if let attachments = message.attachments {
          for (index, attachment) in attachments.enumerated() {
            let insertAttachment = attachmentsTable.insert(
              attachmentIdColumn <- "\(message.id.uuidString)_\(index)",
              attachmentMessageIdColumn <- message.id.uuidString,
              attachmentFileNameColumn <- attachment.fileName,
              attachmentFilePathColumn <- attachment.filePath,
              attachmentFileTypeColumn <- attachment.type,
            )

            try database.run(insertAttachment)
          }
        }
      }
    }
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    try await initializeDatabaseIfNeeded()
    guard oldId != newId else { return }

    // Get the old session details
    guard let oldSessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == oldId)) else {
      return
    }

    try database.transaction {
      // Create the new session record first so message foreign keys can move to it.
      let existingNewSession = try database.pluck(sessionsTable.filter(sessionIdColumn == newId))
      if existingNewSession == nil {
        let insertNewSession = sessionsTable.insert(
          sessionIdColumn <- newId,
          createdAtColumn <- oldSessionRow[createdAtColumn],
          firstUserMessageColumn <- oldSessionRow[firstUserMessageColumn],
          lastAccessedAtColumn <- Date(),
          workingDirectoryColumn <- oldSessionRow[workingDirectoryColumn],
          branchNameColumn <- oldSessionRow[branchNameColumn],
          isWorktreeColumn <- oldSessionRow[isWorktreeColumn],
          usageInputTokensColumn <- oldSessionRow[usageInputTokensColumn],
          usageOutputTokensColumn <- oldSessionRow[usageOutputTokensColumn],
          usageCachedInputTokensColumn <- oldSessionRow[usageCachedInputTokensColumn],
          usageReasoningOutputTokensColumn <- oldSessionRow[usageReasoningOutputTokensColumn]
        )
        try database.run(insertNewSession)
      } else {
        let newSession = sessionsTable.filter(sessionIdColumn == newId)
        let newSessionRow = try database.pluck(newSession)
        try database.run(newSession.update(
          usageInputTokensColumn <- (newSessionRow?[usageInputTokensColumn] ?? 0) + oldSessionRow[usageInputTokensColumn],
          usageOutputTokensColumn <- (newSessionRow?[usageOutputTokensColumn] ?? 0) + oldSessionRow[usageOutputTokensColumn],
          usageCachedInputTokensColumn <- (newSessionRow?[usageCachedInputTokensColumn] ?? 0) + oldSessionRow[usageCachedInputTokensColumn],
          usageReasoningOutputTokensColumn <- (newSessionRow?[usageReasoningOutputTokensColumn] ?? 0) + oldSessionRow[usageReasoningOutputTokensColumn]
        ))
      }

      let oldMessages = messagesTable.filter(messageSessionIdColumn == oldId)
      try database.run(oldMessages.update(messageSessionIdColumn <- newId))

      let deleteOldSession = sessionsTable.filter(sessionIdColumn == oldId)
      try database.run(deleteOldSession.delete())
    }
  }

  public func recordUsage(id: String, usage: SessionUsageRecord) async throws {
    try await initializeDatabaseIfNeeded()

    let session = sessionsTable.filter(sessionIdColumn == id)
    guard let sessionRow = try database.pluck(session) else {
      return
    }

    try database.run(session.update(
      usageInputTokensColumn <- sessionRow[usageInputTokensColumn] + usage.inputTokens,
      usageOutputTokensColumn <- sessionRow[usageOutputTokensColumn] + usage.outputTokens,
      usageCachedInputTokensColumn <- sessionRow[usageCachedInputTokensColumn] + usage.cachedInputTokens,
      usageReasoningOutputTokensColumn <- sessionRow[usageReasoningOutputTokensColumn] + usage.reasoningOutputTokens
    ))
  }

  public func usageSummaryForWorkingDirectory(_ workingDirectory: String?) async throws -> SessionUsageSummary {
    try await initializeDatabaseIfNeeded()

    let normalizedDirectory = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let normalizedDirectory, !normalizedDirectory.isEmpty else {
      return .zero
    }

    let query = sessionsTable.filter(workingDirectoryColumn == normalizedDirectory)
    var summary = SessionUsageSummary.zero
    for sessionRow in try database.prepare(query) {
      summary = summary.adding(usageSummary(from: sessionRow))
    }
    return summary
  }
  
  private var database: Connection!
  private var isInitialized = false
  
  // Table definitions
  private let sessionsTable = Table("sessions")
  private let messagesTable = Table("messages")
  private let attachmentsTable = Table("attachments")
  
  // Session columns
  private let sessionIdColumn = Expression<String>("id")
  private let createdAtColumn = Expression<Date>("created_at")
  private let firstUserMessageColumn = Expression<String>("first_user_message")
  private let lastAccessedAtColumn = Expression<Date>("last_accessed_at")
  private let workingDirectoryColumn = Expression<String?>("working_directory")
  private let branchNameColumn = Expression<String?>("branch_name")
  private let isWorktreeColumn = Expression<Bool>("is_worktree")
  private let usageInputTokensColumn = Expression<Int>("usage_input_tokens")
  private let usageOutputTokensColumn = Expression<Int>("usage_output_tokens")
  private let usageCachedInputTokensColumn = Expression<Int>("usage_cached_input_tokens")
  private let usageReasoningOutputTokensColumn = Expression<Int>("usage_reasoning_output_tokens")
  
  // Message columns
  private let messageIdColumn = Expression<String>("id")
  private let messageSessionIdColumn = Expression<String>("session_id")
  private let messageContentColumn = Expression<String>("content")
  private let messageRoleColumn = Expression<String>("role")
  private let messageTimestampColumn = Expression<Date>("timestamp")
  private let messageTypeColumn = Expression<String>("message_type")
  private let messageToolNameColumn = Expression<String?>("tool_name")
  private let messageToolUseIdColumn = Expression<String?>("tool_use_id")
  private let messageToolInputDataColumn = Expression<String?>("tool_input_data")
  private let messageIsErrorColumn = Expression<Bool>("is_error")
  private let messageIsCompleteColumn = Expression<Bool>("is_complete")
  private let messageWasCancelledColumn = Expression<Bool>("was_cancelled")
  private let messageTaskGroupIdColumn = Expression<String?>("task_group_id")
  private let messageIsTaskContainerColumn = Expression<Bool>("is_task_container")
  
  // Attachment columns
  private let attachmentIdColumn = Expression<String>("id")
  private let attachmentMessageIdColumn = Expression<String>("message_id")
  private let attachmentFileNameColumn = Expression<String>("file_name")
  private let attachmentFilePathColumn = Expression<String>("file_path")
  private let attachmentFileTypeColumn = Expression<String>("file_type")
  
  private func initializeDatabaseIfNeeded() async throws {
    guard !isInitialized else { return }

    // Create database in Application Support directory
    let fileManager = FileManager.default
    let appSupportDir: URL
    if let applicationSupportDirectory {
      appSupportDir = applicationSupportDirectory
    } else {
      appSupportDir = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true,
      )
    }

    // Create application-specific directory within Application Support
    // Structure: ~/Library/Application Support/ClaudeCodeUI/
    let appDir = appSupportDir.appendingPathComponent("ClaudeCodeUI", isDirectory: true)
    try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

    // Create SQLite database file path
    // Final path: ~/Library/Application Support/ClaudeCodeUI/claude_code_sessions.sqlite
    let dbPath = appDir.appendingPathComponent("claude_code_sessions.sqlite").path

    // Initialize SQLite connection using SQLite.swift
    // This creates the database file if it doesn't exist
    database = try Connection(dbPath)

    // Enable foreign key constraints (disabled by default in SQLite)
    try database.execute("PRAGMA foreign_keys = ON")

    // Initialize migration manager
    migrationManager = SimplifiedClaudeCodeSQLiteMigrationManager(
      database: database,
      databasePath: dbPath
    )

    // Run any pending migrations
    try await migrationManager?.runMigrationsIfNeeded()

    // Validate database integrity
    try await migrationManager?.validateDatabase()

    // Create tables (if they don't exist)
    try await createTables()

    // Clean up old backups
    try await migrationManager?.cleanupOldBackups()

    isInitialized = true
  }
  
  private func createTables() async throws {
    // Create sessions table
    try database.run(sessionsTable.create(ifNotExists: true) { table in
      table.column(sessionIdColumn, primaryKey: true)
      table.column(createdAtColumn)
      table.column(firstUserMessageColumn)
      table.column(lastAccessedAtColumn)
      table.column(workingDirectoryColumn)
      table.column(branchNameColumn)
      table.column(isWorktreeColumn, defaultValue: false)
      table.column(usageInputTokensColumn, defaultValue: 0)
      table.column(usageOutputTokensColumn, defaultValue: 0)
      table.column(usageCachedInputTokensColumn, defaultValue: 0)
      table.column(usageReasoningOutputTokensColumn, defaultValue: 0)
    })
    
    // Create messages table
    try database.run(messagesTable.create(ifNotExists: true) { table in
      table.column(messageIdColumn, primaryKey: true)
      table.column(messageSessionIdColumn)
      table.column(messageContentColumn)
      table.column(messageRoleColumn)
      table.column(messageTimestampColumn)
      table.column(messageTypeColumn)
      table.column(messageToolNameColumn)
      table.column(messageToolUseIdColumn)
      table.column(messageToolInputDataColumn)
      table.column(messageIsErrorColumn)
      table.column(messageIsCompleteColumn)
      table.column(messageWasCancelledColumn)
      table.column(messageTaskGroupIdColumn)
      table.column(messageIsTaskContainerColumn)
      table.foreignKey(messageSessionIdColumn, references: sessionsTable, sessionIdColumn, delete: .cascade)
    })
    
    // Create attachments table
    try database.run(attachmentsTable.create(ifNotExists: true) { table in
      table.column(attachmentIdColumn, primaryKey: true)
      table.column(attachmentMessageIdColumn)
      table.column(attachmentFileNameColumn)
      table.column(attachmentFilePathColumn)
      table.column(attachmentFileTypeColumn)
      table.foreignKey(attachmentMessageIdColumn, references: messagesTable, messageIdColumn, delete: .cascade)
    })
  }
  
  private func getMessagesForSession(sessionId: String) async throws -> [ChatMessage] {
    var messages = [ChatMessage]()

    let query = messagesTable
      .filter(messageSessionIdColumn == sessionId)
      .order(messageTimestampColumn.asc)

    var rowCount = 0
    for messageRow in try database.prepare(query) {
      rowCount += 1
      let roleString = messageRow[messageRoleColumn]
      let typeString = messageRow[messageTypeColumn]
      let idString = messageRow[messageIdColumn]

      guard
        let role = MessageRole(rawValue: roleString),
        let messageType = MessageType(rawValue: typeString),
        let messageId = UUID(uuidString: idString)
      else {
        continue
      }
      
      let taskGroupId = messageRow[messageTaskGroupIdColumn].flatMap { UUID(uuidString: $0) }
      
      let message = ChatMessage(
        id: messageId,
        role: role,
        content: messageRow[messageContentColumn],
        timestamp: messageRow[messageTimestampColumn],
        isComplete: messageRow[messageIsCompleteColumn],
        messageType: messageType,
        toolName: messageRow[messageToolNameColumn],
        toolInputData: {
          guard
            let base64String = messageRow[messageToolInputDataColumn],
            let data = Data(base64Encoded: base64String)
          else { return nil }
          return try? JSONDecoder().decode(ToolInputData.self, from: data)
        }(),
        toolUseID: messageRow[messageToolUseIdColumn],
        isError: messageRow[messageIsErrorColumn],
        codeSelections: nil, // Simplified for now
        attachments: nil, // Could load from attachments table if needed
        wasCancelled: messageRow[messageWasCancelledColumn],
        taskGroupId: taskGroupId,
        isTaskContainer: messageRow[messageIsTaskContainerColumn],
      )
      
      messages.append(message)
    }

    return messages
  }

  private func usageSummary(from row: Row) -> SessionUsageSummary {
    SessionUsageSummary(
      inputTokens: row[usageInputTokensColumn],
      outputTokens: row[usageOutputTokensColumn],
      cachedInputTokens: row[usageCachedInputTokensColumn],
      reasoningOutputTokens: row[usageReasoningOutputTokensColumn]
    )
  }
}
