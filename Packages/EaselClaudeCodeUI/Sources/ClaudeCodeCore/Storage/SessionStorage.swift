//
//  SessionStorage.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/14/2025.
//

import Foundation

/// Session data stored for each conversation
public struct StoredSession: Codable, Identifiable, Sendable {
  public let id: String
  public let createdAt: Date
  public let firstUserMessage: String
  public var lastAccessedAt: Date
  /// Complete message history for this session
  public var messages: [ChatMessage]
  /// Working directory for this session
  public let workingDirectory: String?
  /// Git branch name associated with this session
  public let branchName: String?
  /// Whether this session is in a git worktree
  public let isWorktree: Bool
  /// Provider used by this conversation.
  public let provider: ChatProvider
  /// Aggregate token usage recorded for this session.
  public let usageSummary: SessionUsageSummary

  /// Creates a new StoredSession instance.
  /// - Parameters:
  ///   - id: Unique identifier for the session
  ///   - createdAt: When the session was created
  ///   - firstUserMessage: The first message from the user in this session
  ///   - lastAccessedAt: When the session was last accessed
  ///   - messages: Complete message history for this session
  ///   - workingDirectory: Working directory for this session
  ///   - branchName: Git branch name for this session
  ///   - isWorktree: Whether this session is in a git worktree
  public init(
    id: String,
    createdAt: Date,
    firstUserMessage: String,
    lastAccessedAt: Date,
    messages: [ChatMessage] = [],
    workingDirectory: String? = nil,
    branchName: String? = nil,
    isWorktree: Bool = false,
    provider: ChatProvider = .codex,
    usageSummary: SessionUsageSummary = .zero
  ) {
    self.id = id
    self.createdAt = createdAt
    self.firstUserMessage = firstUserMessage
    self.lastAccessedAt = lastAccessedAt
    self.messages = messages
    self.workingDirectory = workingDirectory
    self.branchName = branchName
    self.isWorktree = isWorktree
    self.provider = provider
    self.usageSummary = usageSummary
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case createdAt
    case firstUserMessage
    case lastAccessedAt
    case messages
    case workingDirectory
    case branchName
    case isWorktree
    case provider
    case usageSummary
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    firstUserMessage = try container.decode(String.self, forKey: .firstUserMessage)
    lastAccessedAt = try container.decode(Date.self, forKey: .lastAccessedAt)
    messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
    workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
    branchName = try container.decodeIfPresent(String.self, forKey: .branchName)
    isWorktree = try container.decodeIfPresent(Bool.self, forKey: .isWorktree) ?? false
    provider = try container.decodeIfPresent(ChatProvider.self, forKey: .provider) ?? .codex
    usageSummary = try container.decodeIfPresent(SessionUsageSummary.self, forKey: .usageSummary) ?? .zero
  }
  
  /// Computed title based on first user message
  public var title: String {
    let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "New Session"
    }
    // Take first 50 characters of the message
    let maxLength = 50
    if trimmed.count <= maxLength {
      return trimmed
    }
    return String(trimmed.prefix(maxLength)) + "..."
  }
}

/// Protocol for session storage management
public protocol SessionStorageProtocol {
  /// Saves a new session
  func saveSession(id: String, firstMessage: String, workingDirectory: String?, branchName: String?, isWorktree: Bool, provider: ChatProvider) async throws
  
  /// Retrieves all stored sessions
  func getAllSessions() async throws -> [StoredSession]
  
  /// Retrieves a specific session by ID
  func getSession(id: String) async throws -> StoredSession?
  
  /// Updates the last accessed time for a session
  func updateLastAccessed(id: String) async throws
  
  /// Deletes a session
  func deleteSession(id: String) async throws
  
  /// Deletes all sessions
  func deleteAllSessions() async throws
  
  /// Updates messages for a session
  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws
  
  /// Updates the session ID (when Claude returns a new ID for the same conversation)
  func updateSessionId(oldId: String, newId: String) async throws

  /// Adds token usage for a completed turn.
  func recordUsage(id: String, usage: SessionUsageRecord) async throws

  /// Returns aggregate usage for all sessions associated with a working directory.
  func usageSummaryForWorkingDirectory(_ workingDirectory: String?) async throws -> SessionUsageSummary
}

public extension SessionStorageProtocol {
  func recordUsage(id: String, usage: SessionUsageRecord) async throws {}

  func usageSummaryForWorkingDirectory(_ workingDirectory: String?) async throws -> SessionUsageSummary {
    let normalizedDirectory = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let normalizedDirectory, !normalizedDirectory.isEmpty else {
      return .zero
    }

    let sessions = try await getAllSessions()
    return sessions
      .filter { $0.workingDirectory == normalizedDirectory }
      .map(\.usageSummary)
      .reduce(.zero) { $0.adding($1) }
  }
}

/// No-operation implementation of SessionStorage for direct ChatScreen usage.
/// This implementation doesn't store or load any sessions, avoiding unnecessary overhead.
public actor NoOpSessionStorage: SessionStorageProtocol {
  
  public init() {}
  
  public func saveSession(id: String, firstMessage: String, workingDirectory: String?, branchName: String?, isWorktree: Bool, provider: ChatProvider) async throws {
    // No-op: Don't save anything
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    // Return empty array - no sessions to load
    return []
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    // No session exists
    return nil
  }
  
  public func updateLastAccessed(id: String) async throws {
    // No-op: Nothing to update
  }
  
  public func deleteSession(id: String) async throws {
    // No-op: Nothing to delete
  }
  
  public func deleteAllSessions() async throws {
    // No-op: Nothing to delete
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    // No-op: Don't store messages
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    // No-op: No session to update
  }
}
