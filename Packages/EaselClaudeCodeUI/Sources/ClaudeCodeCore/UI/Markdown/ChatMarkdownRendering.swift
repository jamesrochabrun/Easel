import Foundation

protocol ChatMarkdownRendering {
  func displayMarkdown(for content: String, isComplete: Bool) -> String
}

struct DefaultChatMarkdownRenderer: ChatMarkdownRendering {
  private let fenceNormalizer: ChatMarkdownFenceNormalizing

  init(fenceNormalizer: ChatMarkdownFenceNormalizing = ChatMarkdownFenceNormalizer()) {
    self.fenceNormalizer = fenceNormalizer
  }

  func displayMarkdown(for content: String, isComplete: Bool) -> String {
    guard !isComplete else { return content }
    return fenceNormalizer.normalizedMarkdown(content)
  }
}

protocol ChatMarkdownFenceNormalizing {
  func normalizedMarkdown(_ markdown: String) -> String
}

struct ChatMarkdownFenceNormalizer: ChatMarkdownFenceNormalizing {
  func normalizedMarkdown(_ markdown: String) -> String {
    guard let openFence = unclosedFence(in: markdown) else {
      return markdown
    }

    let newline = markdown.hasSuffix("\n") ? "" : "\n"
    return markdown + newline + String(repeating: String(openFence.character), count: openFence.length)
  }

  private func unclosedFence(in markdown: String) -> MarkdownFence? {
    var openFence: MarkdownFence?
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

    for line in lines {
      guard let fence = fenceMarker(in: line) else { continue }

      if let currentFence = openFence {
        if fence.character == currentFence.character && fence.length >= currentFence.length {
          openFence = nil
        }
      } else {
        openFence = fence
      }
    }

    return openFence
  }

  private func fenceMarker(in line: Substring) -> MarkdownFence? {
    let lineText = String(line)
    let indentation = lineText.prefix { $0 == " " }.count
    guard indentation <= 3 else { return nil }

    let start = lineText.dropFirst(indentation)
    guard let character = start.first, character == "`" || character == "~" else {
      return nil
    }

    let length = start.prefix { $0 == character }.count
    guard length >= 3 else { return nil }

    return MarkdownFence(character: character, length: length)
  }
}

private struct MarkdownFence: Equatable {
  let character: Character
  let length: Int
}
