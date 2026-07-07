import AgentHarness
import Foundation

/// Lists a directory (non-recursive), directories first.
public struct LSTool: AgentTool {

  public let name = "LS"

  public let description = """
    Lists the files and subdirectories directly inside a directory \
    (non-recursive). Directories are listed first with a trailing "/"; \
    files include their size. `path` defaults to the working directory. Use \
    Glob to search recursively by name and Read to view file contents.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "path": [
        "type": "string",
        "description": "Directory to list. Defaults to the working directory.",
      ],
    ],
    "required": [],
  ]

  public let isReadOnly = true

  static let maximumEntries = 500

  public init() {}

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    let requestedPath = arguments["path"]?.stringValue ?? "."
    let resolved: URL
    do {
      resolved = try context.pathPolicy.resolveForRead(requestedPath)
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
      return ToolResult(
        content: "Directory not found: \(requestedPath). Check the path or use Glob to locate it.",
        isError: true
      )
    }
    guard isDirectory.boolValue else {
      return ToolResult(
        content: "\(requestedPath) is a file, not a directory. Use the Read tool to view it.",
        isError: true
      )
    }

    let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
    let entries: [URL]
    do {
      entries = try fileManager.contentsOfDirectory(
        at: resolved,
        includingPropertiesForKeys: keys
      )
    } catch {
      return ToolResult(
        content: "Could not list \(requestedPath): \(error.localizedDescription)",
        isError: true
      )
    }

    if entries.isEmpty {
      return ToolResult(content: "\(resolved.path)/ is empty.")
    }

    struct Entry {
      var name: String
      var isDirectory: Bool
      var size: Int?
    }

    let sorted = entries
      .map { url -> Entry in
        let values = try? url.resourceValues(forKeys: Set(keys))
        return Entry(
          name: url.lastPathComponent,
          isDirectory: values?.isDirectory == true,
          size: values?.fileSize
        )
      }
      .sorted { lhs, rhs in
        if lhs.isDirectory != rhs.isDirectory {
          return lhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }

    var lines = ["\(resolved.path)/:"]
    for entry in sorted.prefix(Self.maximumEntries) {
      if entry.isDirectory {
        lines.append("  \(entry.name)/")
      } else {
        lines.append("  \(entry.name) (\(Self.formatSize(entry.size ?? 0)))")
      }
    }
    if sorted.count > Self.maximumEntries {
      lines.append("  … [\(sorted.count - Self.maximumEntries) more entries not shown]")
    }
    return ToolResult(content: lines.joined(separator: "\n"))
  }

  private static func formatSize(_ bytes: Int) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024, unitIndex < units.count - 1 {
      value /= 1024
      unitIndex += 1
    }
    if unitIndex == 0 {
      return "\(bytes) B"
    }
    return String(format: "%.1f %@", value, units[unitIndex])
  }
}
