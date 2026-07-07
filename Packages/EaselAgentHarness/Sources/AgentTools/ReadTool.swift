import AgentHarness
import Foundation

/// Reads a text file from the workspace with `cat -n` style line numbers.
public struct ReadTool: AgentTool {

  public let name = "Read"

  public let description = """
    Reads a file from the project workspace. Returns the content with line \
    numbers in `cat -n` format (line number, tab, line text). By default it \
    reads up to 2000 lines from the start; pass `offset` (1-based line \
    number) and `limit` to read a specific window of a large file. Very long \
    lines are truncated. You must Read a file before you can Write over it \
    or Edit it. Paths may be relative to the working directory or absolute \
    inside it.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "file_path": [
        "type": "string",
        "description": "Path of the file to read (relative to the working directory, or absolute).",
      ],
      "offset": [
        "type": "number",
        "description": "1-based line number to start reading from. Defaults to 1.",
      ],
      "limit": [
        "type": "number",
        "description": "Maximum number of lines to read. Defaults to 2000.",
      ],
    ],
    "required": ["file_path"],
  ]

  public let isReadOnly = true

  static let defaultLineLimit = 2000
  static let maximumLineLength = 2000
  static let binarySniffLength = 8 * 1024

  private let registry: FileReadRegistry

  public init(registry: FileReadRegistry) {
    self.registry = registry
  }

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let filePath = arguments["file_path"]?.stringValue, !filePath.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'file_path'. Provide the path of the file to read.",
        isError: true
      )
    }

    let resolved: URL
    do {
      resolved = try context.pathPolicy.resolveForRead(filePath)
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
      return ToolResult(
        content: Self.missingFileMessage(for: filePath, resolved: resolved),
        isError: true
      )
    }
    if isDirectory.boolValue {
      return ToolResult(
        content: "\(filePath) is a directory, not a file. Use the LS tool to list its contents.",
        isError: true
      )
    }

    let data: Data
    do {
      data = try Data(contentsOf: resolved)
    } catch {
      return ToolResult(
        content: "Could not read \(filePath): \(error.localizedDescription)",
        isError: true
      )
    }

    if data.prefix(Self.binarySniffLength).contains(0) {
      return ToolResult(
        content: "\(filePath) looks like a binary file and cannot be shown as text.",
        isError: true
      )
    }

    let modificationDate = (try? fileManager.attributesOfItem(atPath: resolved.path)[.modificationDate] as? Date) ?? Date()
    await registry.recordRead(path: resolved.path, modificationDate: modificationDate)

    let text = String(decoding: data, as: UTF8.self)
    if text.isEmpty {
      return ToolResult(content: "(file is empty)", uiHints: ["file_path": filePath])
    }

    var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    // A trailing newline produces one empty trailing element; drop it so the
    // line count matches what editors and `wc -l` report.
    if lines.last == "" {
      lines.removeLast()
    }
    let totalLines = lines.count

    let offset = max(arguments["offset"]?.intValue ?? 1, 1)
    let limit = max(arguments["limit"]?.intValue ?? Self.defaultLineLimit, 1)
    guard offset <= totalLines else {
      return ToolResult(
        content: "Offset \(offset) is past the end of the file: \(filePath) has only \(totalLines) line\(totalLines == 1 ? "" : "s").",
        isError: true
      )
    }

    let endExclusive = min(offset - 1 + limit, totalLines)
    var numbered: [String] = []
    numbered.reserveCapacity(endExclusive - (offset - 1))
    for index in (offset - 1)..<endExclusive {
      var line = lines[index]
      if line.count > Self.maximumLineLength {
        line = String(line.prefix(Self.maximumLineLength)) + "… [line truncated]"
      }
      numbered.append(String(format: "%6d\t%@", index + 1, line))
    }

    var content = numbered.joined(separator: "\n")
    if endExclusive < totalLines {
      content += "\n… [showing lines \(offset)-\(endExclusive) of \(totalLines); use offset/limit to read more]"
    }
    return ToolResult(content: content, uiHints: ["file_path": filePath])
  }

  /// Error message for a missing file, with a hint listing the nearest
  /// existing parent directory's contents so the model can correct the path.
  private static func missingFileMessage(for originalPath: String, resolved: URL) -> String {
    let fileManager = FileManager.default
    var ancestor = resolved.deletingLastPathComponent()
    while !fileManager.fileExists(atPath: ancestor.path), ancestor.path != "/" {
      ancestor = ancestor.deletingLastPathComponent()
    }
    var message = "File not found: \(originalPath)."
    if let entries = try? fileManager.contentsOfDirectory(atPath: ancestor.path), !entries.isEmpty {
      let shown = entries.sorted().prefix(20)
      message += " Nearest existing directory \(ancestor.path) contains: \(shown.joined(separator: ", "))"
      if entries.count > shown.count {
        message += ", …"
      }
      message += ". Check the path or use Glob/LS to locate the file."
    } else {
      message += " Check the path or use Glob/LS to locate the file."
    }
    return message
  }
}
