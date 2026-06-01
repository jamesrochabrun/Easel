import HighlightSwift
import XCTest
@testable import ClaudeCodeCore

final class ChatMarkdownRenderingTests: XCTestCase {
  func testCompletedMarkdownIsNotChanged() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    # Heading

    - Item
    - [Link](https://example.com)

    ```swift
    let value = 1
    ```
    """

    XCTAssertEqual(renderer.displayMarkdown(for: markdown, isComplete: true), markdown)
  }

  func testStreamingMarkdownClosesUnfinishedBacktickFenceForDisplay() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    Before

    ```swift
    let value = 1
    """

    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: false),
      """
      Before

      ```swift
      let value = 1
      ```
      """
    )
  }

  func testStreamingMarkdownClosesUnfinishedTildeFenceWithMatchingLength() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    ~~~~json
    {"name":"Easel"}
    """

    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: false),
      """
      ~~~~json
      {"name":"Easel"}
      ~~~~
      """
    )
  }

  func testClosedStreamingFenceIsNotChanged() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    ```swift
    let value = 1
    ```

    Done
    """

    XCTAssertEqual(renderer.displayMarkdown(for: markdown, isComplete: false), markdown)
  }

  func testLanguageMapperUsesKnownHighlightLanguages() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.highlightMode(for: "swift"), .languageIgnoreIllegal(.swift))
    XCTAssertEqual(mapper.highlightMode(for: "ts"), .languageIgnoreIllegal(.typeScript))
    XCTAssertEqual(mapper.highlightMode(for: "bash"), .languageIgnoreIllegal(.bash))
  }

  func testLanguageMapperNormalizesFenceInfoAndUnknownAliases() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.highlightMode(for: "swift:Sources/App.swift"), .languageIgnoreIllegal(.swift))
    XCTAssertEqual(mapper.highlightMode(for: "customlang title"), .languageAliasIgnoreIllegal("customlang"))
    XCTAssertEqual(mapper.highlightMode(for: nil), .automatic)
  }

  func testLanguageMapperProvidesDisplayNamesForAliases() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.displayName(for: "ts"), "typescript")
    XCTAssertEqual(mapper.displayName(for: "py"), "python")
    XCTAssertEqual(mapper.displayName(for: "swift:Sources/App.swift"), "swift")
  }

  func testLanguageMapperIdentifiesMermaidFenceInfo() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertTrue(mapper.isMermaid("mermaid"))
    XCTAssertTrue(mapper.isMermaid("mermaid diagram"))
    XCTAssertFalse(mapper.isMermaid("markdown"))
  }
}
