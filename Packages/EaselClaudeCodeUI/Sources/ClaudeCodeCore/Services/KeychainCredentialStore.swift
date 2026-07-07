//
//  KeychainCredentialStore.swift
//  ClaudeCodeUI
//

import Foundation
import Security

/// Keychain-backed `CredentialStore` for API-provider secrets.
///
/// Items are generic passwords under a single service, with the
/// endpoint-profile id as the account. Keys are readable after the first
/// unlock so background agent runs keep working while the screen is locked.
public struct KeychainCredentialStore: CredentialStore {
  public static let defaultService = "com.easel.api-provider"

  private let service: String

  /// - Parameter service: Keychain service name. Override in tests to keep
  ///   test residue isolated from real user credentials.
  public init(service: String = KeychainCredentialStore.defaultService) {
    self.service = service
  }

  public func apiKey(for profileId: String) throws -> String? {
    var query = baseQuery(account: profileId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    switch status {
    case errSecSuccess:
      guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
        throw KeychainCredentialStoreError.invalidItemData
      }
      return key
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainCredentialStoreError.unexpectedStatus(status)
    }
  }

  public func setAPIKey(_ key: String?, for profileId: String) throws {
    guard let key else {
      try deleteAPIKey(for: profileId)
      return
    }

    let data = Data(key.utf8)
    let updateStatus = SecItemUpdate(
      baseQuery(account: profileId) as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )

    switch updateStatus {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var addQuery = baseQuery(account: profileId)
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainCredentialStoreError.unexpectedStatus(addStatus)
      }
    default:
      throw KeychainCredentialStoreError.unexpectedStatus(updateStatus)
    }
  }

  private func deleteAPIKey(for profileId: String) throws {
    let status = SecItemDelete(baseQuery(account: profileId) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainCredentialStoreError.unexpectedStatus(status)
    }
  }

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

/// Failures surfaced by `KeychainCredentialStore`.
public enum KeychainCredentialStoreError: LocalizedError, Equatable {
  case unexpectedStatus(OSStatus)
  case invalidItemData

  public var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
      return "Keychain operation failed: \(detail)"
    case .invalidItemData:
      return "The stored API key could not be read from the Keychain."
    }
  }
}
