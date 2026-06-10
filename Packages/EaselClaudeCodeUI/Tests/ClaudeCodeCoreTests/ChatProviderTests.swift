import XCTest
@testable import ClaudeCodeCore

final class ChatProviderTests: XCTestCase {

  func testOnlyCodexIsAdvertisedAsAvailableProvider() {
    XCTAssertEqual(ChatProvider.allCases, [.codex])
  }

  func testClaudeProviderNormalizesToCodex() {
    XCTAssertEqual(ChatProvider.claude.supportedProvider, .codex)
    XCTAssertEqual(ChatProvider.codex.supportedProvider, .codex)
  }
}
