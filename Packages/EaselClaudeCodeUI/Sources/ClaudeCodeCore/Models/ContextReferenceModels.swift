//
//  ContextReferenceModels.swift
//  ClaudeCodeUI
//

import Foundation

/// Represents information about a file included as chat context.
public struct FileInfo: Equatable, Identifiable, Codable {
  public let id: UUID

  /// Full path to the file
  public let path: String

  /// File name without path
  public let name: String

  /// File content, loaded on demand when needed
  public let content: String?

  /// File extension
  public var fileExtension: String? {
    URL(fileURLWithPath: path).pathExtension.isEmpty ? nil : URL(fileURLWithPath: path).pathExtension
  }

  /// Programming language based on file extension
  public var language: String? {
    guard let ext = fileExtension else { return nil }
    switch ext.lowercased() {
    case "swift": return "swift"
    case "m", "mm": return "objective-c"
    case "h", "hpp": return "c++"
    case "js", "jsx": return "javascript"
    case "ts", "tsx": return "typescript"
    case "py": return "python"
    case "rb": return "ruby"
    case "java": return "java"
    case "kt": return "kotlin"
    case "go": return "go"
    case "rs": return "rust"
    case "php": return "php"
    case "cs": return "csharp"
    case "sh", "bash": return "bash"
    case "yml", "yaml": return "yaml"
    case "json": return "json"
    case "xml": return "xml"
    case "md": return "markdown"
    default: return nil
    }
  }

  public init(id: UUID = UUID(), path: String, name: String? = nil, content: String? = nil) {
    self.id = id
    self.path = path
    self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
    self.content = content
  }
}

/// Represents a text selection in a file.
public struct TextSelection: Equatable, Identifiable, Codable, Sendable {
  public let id: UUID

  /// Path to the file containing the selection
  public let filePath: String

  /// The selected text
  public let selectedText: String

  /// Line range of the selection, 1-based
  public let lineRange: ClosedRange<Int>

  /// Column range on the start line, stored as optional lower/upper bounds for Codable
  public let columnRangeLower: Int?
  public let columnRangeUpper: Int?

  /// Timestamp when the selection was captured
  public let timestamp: Date

  /// Column range computed property for compatibility
  public var columnRange: Range<Int>? {
    guard let lower = columnRangeLower, let upper = columnRangeUpper else { return nil }
    return lower..<upper
  }

  /// File name for display
  public var fileName: String {
    URL(fileURLWithPath: filePath).lastPathComponent
  }

  /// Formatted line range for display
  public var lineRangeDescription: String {
    if lineRange.lowerBound == lineRange.upperBound {
      return "Line \(lineRange.lowerBound)"
    } else {
      return "Lines \(lineRange.lowerBound)-\(lineRange.upperBound)"
    }
  }

  public init(
    id: UUID = UUID(),
    filePath: String,
    selectedText: String,
    lineRange: ClosedRange<Int>,
    columnRange: Range<Int>? = nil,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.filePath = filePath
    self.selectedText = selectedText
    self.lineRange = lineRange
    self.columnRangeLower = columnRange?.lowerBound
    self.columnRangeUpper = columnRange?.upperBound
    self.timestamp = timestamp
  }
}
