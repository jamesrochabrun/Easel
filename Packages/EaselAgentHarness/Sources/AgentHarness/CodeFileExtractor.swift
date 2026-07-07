import Foundation

/// A file recovered from a fenced code block in an assistant message.
public struct ExtractedCodeFile: Sendable, Equatable {
  public let relativePath: String
  public let content: String

  public init(relativePath: String, content: String) {
    self.relativePath = relativePath
    self.content = content
  }
}

/// Recovers savable files from assistant text for weak models that answer a
/// "build a page" request by pasting the code into the chat instead of calling
/// the Write tool.
///
/// Recognizes:
/// - a complete HTML document (`<!doctype html>` / `<html>…</html>`) → the
///   entry point `index.html`, regardless of any label;
/// - fenced blocks whose info string names a file (```css styles.css) → that
///   file.
///
/// The host decides whether to apply the result — the recommended guard is
/// "only apply when a complete HTML document is present", which signals the
/// model was authoring a page rather than explaining a snippet.
public enum CodeFileExtractor {

  public static let entryPoint = "index.html"

  public static func extractFiles(from text: String) -> [ExtractedCodeFile] {
    var byPath: [String: String] = [:]
    var order: [String] = []

    for block in fencedBlocks(in: text) {
      let trimmedBody = block.body.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedBody.isEmpty else { continue }

      let path: String?
      if isCompleteHTMLDocument(trimmedBody) {
        // A full document is the page that renders — always the entry point.
        path = entryPoint
      } else if let named = filename(fromInfoString: block.info) {
        path = named
      } else {
        path = nil
      }

      guard let resolved = path else { continue }
      if byPath[resolved] == nil { order.append(resolved) }
      // Last block for a path wins (models sometimes restate the final version).
      byPath[resolved] = block.body
    }

    return order.map { ExtractedCodeFile(relativePath: $0, content: byPath[$0]!) }
  }

  /// True when the extracted set represents an authored page (contains a
  /// complete HTML document) rather than explanatory snippets.
  public static func containsEntryPoint(_ files: [ExtractedCodeFile]) -> Bool {
    files.contains { $0.relativePath == entryPoint }
  }

  // MARK: - Classification

  static func isCompleteHTMLDocument(_ body: String) -> Bool {
    let lower = body.lowercased()
    if lower.hasPrefix("<!doctype html") { return true }
    return lower.contains("<html") && lower.contains("</html>")
  }

  static func filename(fromInfoString info: String) -> String? {
    // e.g. "css styles.css", "html:index.html", "javascript app.js"
    for token in info.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "," }) {
      let candidate = String(token).trimmingCharacters(in: .whitespaces)
      if looksLikeFilename(candidate) { return candidate }
    }
    return nil
  }

  private static let savableExtensions: Set<String> = [
    "html", "htm", "css", "js", "mjs", "json", "svg", "md", "txt", "ts", "jsx", "tsx", "xml",
  ]

  private static func looksLikeFilename(_ candidate: String) -> Bool {
    guard candidate.contains("."),
          !candidate.contains(" "),
          candidate.count < 120,
          !candidate.hasPrefix("/"),
          !candidate.contains("..")
    else { return false }
    let ext = candidate.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
    return savableExtensions.contains(ext)
  }

  // MARK: - Fence scanning

  private struct Fence {
    let info: String
    let body: String
  }

  private static func fencedBlocks(in text: String) -> [Fence] {
    var blocks: [Fence] = []
    let lines = text.components(separatedBy: "\n")
    var index = 0
    while index < lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("```") else {
        index += 1
        continue
      }
      let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
      var body: [String] = []
      index += 1
      var closed = false
      while index < lines.count {
        if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
          closed = true
          index += 1
          break
        }
        body.append(lines[index])
        index += 1
      }
      // Ignore an unterminated fence (a stray ``` with no closer).
      if closed {
        blocks.append(Fence(info: info, body: body.joined(separator: "\n")))
      }
    }
    return blocks
  }
}
