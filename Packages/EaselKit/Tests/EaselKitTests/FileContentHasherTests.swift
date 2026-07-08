//
//  FileContentHasherTests.swift
//  EaselKitTests
//

import Foundation
import Testing
@testable import EaselKit

struct FileContentHasherTests {

  @Test
  func hashesKnownVector() {
    // SHA-256("abc") — FIPS 180-2 test vector.
    let digest = FileContentHasher.sha256(of: Data("abc".utf8))
    #expect(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  }

  @Test
  func emptyDataHashMatchesKnownVector() {
    let digest = FileContentHasher.sha256(of: Data())
    #expect(digest == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  }

  @Test
  func fileHashMatchesDataHash() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("hasher-test-\(UUID().uuidString).bin")
    defer { try? FileManager.default.removeItem(at: url) }

    // Larger than one streaming chunk to exercise the loop.
    var data = Data()
    for byte in 0..<(1_048_576 * 2 + 37) {
      data.append(UInt8(truncatingIfNeeded: byte))
    }
    try data.write(to: url)

    let fileDigest = try FileContentHasher.sha256OfFile(at: url.path)
    #expect(fileDigest == FileContentHasher.sha256(of: data))
  }

  @Test
  func missingFileThrows() {
    #expect(throws: (any Error).self) {
      _ = try FileContentHasher.sha256OfFile(at: "/nonexistent/\(UUID().uuidString)")
    }
  }
}
