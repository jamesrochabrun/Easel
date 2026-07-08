//
//  FileContentHasher.swift
//  EaselKit
//
//  SHA-256 content hashing used for shadow-workspace manifests and drift
//  detection. File hashing streams in chunks so large assets don't load
//  fully into memory.
//

import CryptoKit
import Foundation

// MARK: - FileContentHasher

public enum FileContentHasher {

  public static func sha256(of data: Data) -> String {
    hexString(SHA256.hash(data: data))
  }

  public static func sha256OfFile(at path: String) throws -> String {
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? handle.close() }

    var hasher = SHA256()
    while true {
      guard let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty else {
        break
      }
      hasher.update(data: chunk)
    }
    return hexString(hasher.finalize())
  }

  private static func hexString(_ digest: SHA256.Digest) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
  }
}
