//
//  CredentialStore.swift
//  ClaudeCodeUI
//

import Foundation

/// Storage for API-provider secrets, keyed by endpoint-profile id.
/// Secrets never live in `GlobalPreferencesStorage` (plaintext JSON) — the
/// production implementation is Keychain-backed (workstream E).
public protocol CredentialStore: Sendable {
  func apiKey(for profileId: String) throws -> String?
  /// Passing nil deletes the stored key.
  func setAPIKey(_ key: String?, for profileId: String) throws
}

/// Test/preview implementation.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [String: String] = [:]

  public init() {}

  public func apiKey(for profileId: String) throws -> String? {
    lock.lock()
    defer { lock.unlock() }
    return storage[profileId]
  }

  public func setAPIKey(_ key: String?, for profileId: String) throws {
    lock.lock()
    defer { lock.unlock() }
    storage[profileId] = key
  }
}
