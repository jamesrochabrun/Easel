import XCTest
@testable import ClaudeCodeCore

final class ChatProviderTests: XCTestCase {

  func testCodexAndClaudeAreAdvertisedAsAvailableProviders() {
    XCTAssertEqual(ChatProvider.allCases, [.codex, .claude])
  }

  func testSupportedProviderPreservesSelection() {
    XCTAssertEqual(ChatProvider.claude.supportedProvider, .claude)
    XCTAssertEqual(ChatProvider.codex.supportedProvider, .codex)
  }
}
