//
//  ChatMarkdownRenderingTests.swift
//  EaselTests
//

import HighlightSwift
import Testing
@testable import ClaudeCodeCore

struct ChatMarkdownRenderingTests {
  @Test
  func completedMarkdownIsNotChanged() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    # Heading

    - Item
    - [Link](https://example.com)

    ```swift
    let value = 1
    ```
    """

    #expect(renderer.displayMarkdown(for: markdown, isComplete: true) == markdown)
  }

  @Test
  func streamingMarkdownClosesUnfinishedFenceForDisplay() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    Before

    ```swift
    let value = 1
    """

    #expect(renderer.displayMarkdown(for: markdown, isComplete: false) == """
    Before

    ```swift
    let value = 1
    ```
    """)
  }

  @Test
  func languageMapperNormalizesHighlightLanguages() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    #expect(mapper.highlightMode(for: "swift:Sources/App.swift") == .languageIgnoreIllegal(.swift))
    #expect(mapper.highlightMode(for: "tsx") == .languageIgnoreIllegal(.typeScript))
    #expect(mapper.displayName(for: "py") == "python")
    #expect(mapper.isMermaid("mermaid diagram"))
  }
}
