import AgentHarness
import Foundation

/// Writes (creates or fully replaces) a file inside the workspace.
public struct WriteTool: AgentTool {

  public let name = "Write"

  public let description = """
    Writes a file in the project workspace, creating it (including any \
    missing parent directories) or completely replacing its existing \
    content. To overwrite an existing file you must Read it first in this \
    session, otherwise the call is rejected. Prefer the Edit tool for \
    partial changes to an existing file — use Write only for new files or \
    intentional full rewrites.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "file_path": [
        "type": "string",
        "description": "Path of the file to write (relative to the working directory, or absolute).",
      ],
      "content": [
        "type": "string",
        "description": "The full content the file should contain after writing.",
      ],
    ],
    "required": ["file_path", "content"],
  ]

  public let isReadOnly = false

  private let registry: FileReadRegistry

  public init(registry: FileReadRegistry) {
    self.registry = registry
  }

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let filePath = arguments["file_path"]?.stringValue, !filePath.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'file_path'. Provide the path of the file to write.",
        isError: true
      )
    }
    guard let content = arguments["content"]?.stringValue else {
      return ToolResult(
        content: "Missing required parameter 'content'. Provide the full file content as a string.",
        isError: true
      )
    }

    let resolved: URL
    do {
      resolved = try context.pathPolicy.resolveForWrite(filePath)
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    let exists = fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory)
    if exists, isDirectory.boolValue {
      return ToolResult(
        content: "\(filePath) is a directory. Provide a file path.",
        isError: true
      )
    }
    if exists {
      let hasRead = await registry.hasRead(resolved.path)
      guard hasRead else {
        return ToolResult(
          content: "\(filePath) already exists but has not been read. Read the file first with the Read tool, then Write (or better, use Edit for a partial change).",
          isError: true
        )
      }
    }

    do {
      try fileManager.createDirectory(
        at: resolved.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try Data(content.utf8).write(to: resolved)
    } catch {
      return ToolResult(
        content: "Could not write \(filePath): \(error.localizedDescription)",
        isError: true
      )
    }

    let modificationDate = (try? fileManager.attributesOfItem(atPath: resolved.path)[.modificationDate] as? Date) ?? Date()
    await registry.recordRead(path: resolved.path, modificationDate: modificationDate)

    let bytes = content.utf8.count
    var lineCount = content.split(separator: "\n", omittingEmptySubsequences: false).count
    if content.hasSuffix("\n") || content.isEmpty {
      lineCount -= 1
    }
    return ToolResult(
      content: "\(exists ? "Updated" : "Created") \(filePath) (\(bytes) bytes, \(lineCount) line\(lineCount == 1 ? "" : "s")).",
      uiHints: ["file_path": filePath]
    )
  }
}
