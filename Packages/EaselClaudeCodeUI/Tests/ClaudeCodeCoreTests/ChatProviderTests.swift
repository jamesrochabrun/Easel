import XCTest
@testable import ClaudeCodeCore

final class ChatProviderTests: XCTestCase {

  func testAdvertisedProviders() {
    XCTAssertEqual(ChatProvider.allCases, [.codex, .claude, .api])
  }

  func testSupportedProviderPreservesSelection() {
    XCTAssertEqual(ChatProvider.claude.supportedProvider, .claude)
    XCTAssertEqual(ChatProvider.codex.supportedProvider, .codex)
    XCTAssertEqual(ChatProvider.api.supportedProvider, .api)
  }

  func testDecodingKnownRawValues() throws {
    let decoder = JSONDecoder()
    XCTAssertEqual(try decoder.decode(ChatProvider.self, from: Data("\"claude\"".utf8)), .claude)
    XCTAssertEqual(try decoder.decode(ChatProvider.self, from: Data("\"codex\"".utf8)), .codex)
    XCTAssertEqual(try decoder.decode(ChatProvider.self, from: Data("\"api\"".utf8)), .api)
  }

  func testDecodingUnknownRawValueFallsBackToDefault() throws {
    // Data written by a newer app version must not fail session/prefs decode.
    let decoded = try JSONDecoder().decode(ChatProvider.self, from: Data("\"some-future-provider\"".utf8))
    XCTAssertEqual(decoded, .codex)
  }

  func testEncodingUsesRawValue() throws {
    let data = try JSONEncoder().encode(ChatProvider.api)
    XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"api\"")
  }
}
