import Foundation
import XCTest
@testable import ClaudeCodeCore

final class StoredSessionTests: XCTestCase {

  func testDecodeDefaultsProviderToCodexForLegacySessions() throws {
    let json = """
    {
      "id": "legacy-session",
      "firstUserMessage": "hello",
      "createdAt": "2026-06-17T20:00:00Z",
      "lastAccessedAt": "2026-06-17T20:00:00Z",
      "messages": []
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try XCTUnwrap(json.data(using: .utf8))
    let session = try decoder.decode(StoredSession.self, from: data)

    XCTAssertEqual(session.provider, .codex)
  }
}
