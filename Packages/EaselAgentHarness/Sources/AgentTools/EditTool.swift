import AgentHarness
import Foundation

/// Performs an exact string replacement in an existing workspace file.
public struct EditTool: AgentTool {

  public let name = "Edit"

  public let description = """
    Replaces an exact string in an existing file. `old_string` must match \
    the current file content exactly, including whitespace and indentation, \
    and must be unique in the file — include enough surrounding lines to \
    make it unique, or set `replace_all` to true to replace every \
    occurrence. You must Read the file before editing it; if the file \
    changed on disk since your last Read, re-read it and retry. Prefer this \
    tool over Write for modifying existing files.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "file_path": [
        "type": "string",
        "description": "Path of the file to edit (relative to the working directory, or absolute).",
      ],
      "old_string": [
        "type": "string",
        "description": "Exact existing text to replace, including whitespace and indentation.",
      ],
      "new_string": [
        "type": "string",
        "description": "The replacement text (must differ from old_string).",
      ],
      "replace_all": [
        "type": "boolean",
        "description": "Replace every occurrence of old_string instead of requiring a unique match. Defaults to false.",
      ],
    ],
    "required": ["file_path", "old_string", "new_string"],
  ]

  public let isReadOnly = false

  private let registry: FileReadRegistry

  public init(registry: FileReadRegistry) {
    self.registry = registry
  }

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let filePath = arguments["file_path"]?.stringValue, !filePath.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'file_path'. Provide the path of the file to edit.",
        isError: true
      )
    }
    guard let oldString = arguments["old_string"]?.stringValue else {
      return ToolResult(
        content: "Missing required parameter 'old_string'. Provide the exact text to replace.",
        isError: true
      )
    }
    guard let newString = arguments["new_string"]?.stringValue else {
      return ToolResult(
        content: "Missing required parameter 'new_string'. Provide the replacement text.",
        isError: true
      )
    }
    guard !oldString.isEmpty else {
      return ToolResult(
        content: "old_string must not be empty. Provide the exact existing text to replace; use Write to create new files.",
        isError: true
      )
    }
    guard oldString != newString else {
      return ToolResult(
        content: "old_string and new_string are identical — there is nothing to change. Provide a new_string that differs from old_string.",
        isError: true
      )
    }
    let replaceAll = arguments["replace_all"]?.boolValue ?? false

    let resolved: URL
    do {
      resolved = try context.pathPolicy.resolveForWrite(filePath)
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: resolved.path) else {
      return ToolResult(
        content: "File not found: \(filePath). Edit only modifies existing files — use Write to create a new file.",
        isError: true
      )
    }

    guard let recordedDate = await registry.modificationDateAtRead(for: resolved.path) else {
      return ToolResult(
        content: "\(filePath) has not been read yet. Read the file first with the Read tool, then retry the edit.",
        isError: true
      )
    }
    let currentDate = (try? fileManager.attributesOfItem(atPath: resolved.path)[.modificationDate] as? Date)
    if let currentDate, currentDate != recordedDate {
      return ToolResult(
        content: "\(filePath) has been modified on disk since it was last read. Re-read the file with the Read tool to see the current content, then retry the edit.",
        isError: true
      )
    }

    let content: String
    do {
      content = String(decoding: try Data(contentsOf: resolved), as: UTF8.self)
    } catch {
      return ToolResult(
        content: "Could not read \(filePath): \(error.localizedDescription)",
        isError: true
      )
    }

    let matchCount = content.components(separatedBy: oldString).count - 1
    if matchCount == 0 {
      return ToolResult(
        content: "old_string was not found in \(filePath). It must match the file content exactly, including whitespace, indentation, and line breaks. Read the file to check the current content, then retry with the exact text.",
        isError: true
      )
    }
    if matchCount > 1, !replaceAll {
      return ToolResult(
        content: "old_string matches \(matchCount) places in \(filePath) but must be unique. Either include more surrounding context in old_string so it matches exactly once, or set replace_all to true to replace all \(matchCount) occurrences.",
        isError: true
      )
    }

    let updated: String
    if replaceAll {
      updated = content.replacingOccurrences(of: oldString, with: newString)
    } else if let range = content.range(of: oldString) {
      updated = content.replacingCharacters(in: range, with: newString)
    } else {
      updated = content
    }

    do {
      try Data(updated.utf8).write(to: resolved)
    } catch {
      return ToolResult(
        content: "Could not write \(filePath): \(error.localizedDescription)",
        isError: true
      )
    }

    let modificationDate = (try? fileManager.attributesOfItem(atPath: resolved.path)[.modificationDate] as? Date) ?? Date()
    await registry.recordRead(path: resolved.path, modificationDate: modificationDate)

    let replaced = replaceAll ? matchCount : 1
    return ToolResult(
      content: "Replaced \(replaced) occurrence\(replaced == 1 ? "" : "s") in \(filePath).",
      uiHints: ["file_path": filePath]
    )
  }
}
