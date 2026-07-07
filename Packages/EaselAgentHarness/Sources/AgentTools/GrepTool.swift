import AgentHarness
import Foundation

/// Searches file contents with an extended regular expression (via grep).
public struct GrepTool: AgentTool {

  public let name = "Grep"

  public let description = """
    Searches file contents recursively using an extended (POSIX ERE) regular \
    expression. Returns matching lines with file paths and line numbers by \
    default; set `output_mode` to "files_with_matches" for just the file \
    paths, or "count" for per-file match counts. Pass `path` to search a \
    file or subdirectory (defaults to the working directory), `glob` to \
    filter by filename (e.g. "*.swift"), and `-i` for case-insensitive \
    matching. Binary files and .git/node_modules/.build/dist are skipped. \
    Finding no matches is a normal result, not an error. Use Glob to find \
    files by name.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "pattern": [
        "type": "string",
        "description": "Extended regular expression to search for.",
      ],
      "path": [
        "type": "string",
        "description": "File or directory to search. Defaults to the working directory.",
      ],
      "glob": [
        "type": "string",
        "description": "Only search files whose name matches this glob, e.g. \"*.swift\".",
      ],
      "-i": [
        "type": "boolean",
        "description": "Case-insensitive matching. Defaults to false.",
      ],
      "output_mode": [
        "type": "string",
        "enum": ["content", "files_with_matches", "count"],
        "description": "\"content\" (default) shows matching lines with line numbers; \"files_with_matches\" lists file paths; \"count\" shows per-file match counts.",
      ],
    ],
    "required": ["pattern"],
  ]

  public let isReadOnly = true

  public init() {}

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let pattern = arguments["pattern"]?.stringValue, !pattern.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'pattern'. Provide an extended regular expression to search for.",
        isError: true
      )
    }

    let outputMode = arguments["output_mode"]?.stringValue ?? "content"
    guard ["content", "files_with_matches", "count"].contains(outputMode) else {
      return ToolResult(
        content: "Invalid output_mode \"\(outputMode)\". Use \"content\", \"files_with_matches\", or \"count\".",
        isError: true
      )
    }

    let searchPath: URL
    do {
      searchPath = try context.pathPolicy.resolveForRead(arguments["path"]?.stringValue ?? ".")
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }
    guard FileManager.default.fileExists(atPath: searchPath.path) else {
      return ToolResult(
        content: "Search path does not exist: \(searchPath.path). Pass an existing file or directory, or omit 'path'.",
        isError: true
      )
    }

    var grepArguments = [
      "-R", "-I", "-E",
      "--exclude-dir=.git",
      "--exclude-dir=node_modules",
      "--exclude-dir=.build",
      "--exclude-dir=dist",
    ]
    switch outputMode {
    case "files_with_matches":
      grepArguments.append("-l")
    case "count":
      grepArguments.append("-c")
    default:
      grepArguments.append("-n")
    }
    if arguments["-i"]?.boolValue == true {
      grepArguments.append("-i")
    }
    if let glob = arguments["glob"]?.stringValue, !glob.isEmpty {
      grepArguments.append("--include=\(glob)")
    }
    grepArguments.append(contentsOf: ["-e", pattern, searchPath.path])

    let result: ProcessRunResult
    do {
      result = try await ProcessRunner.run(
        executablePath: "/usr/bin/grep",
        arguments: grepArguments,
        workingDirectory: context.workingDirectory,
        environmentOverrides: context.environment,
        timeoutMilliseconds: BashTool.defaultTimeoutMilliseconds
      )
    } catch {
      return ToolResult(content: "Failed to run grep: \(error.localizedDescription)", isError: true)
    }

    if result.timedOut {
      return ToolResult(
        content: "Search timed out. Narrow the pattern, path, or glob filter and try again.",
        isError: true
      )
    }

    switch result.exitCode {
    case 0:
      var output = result.standardOutput
      if outputMode == "count" {
        // grep -c reports every searched file, including zero-match ones; keep
        // only files that actually matched.
        output = output
          .split(separator: "\n", omittingEmptySubsequences: true)
          .filter { !$0.hasSuffix(":0") }
          .joined(separator: "\n")
      }
      let trimmed = output.isEmpty ? "No matches found." : output
      return ToolResult(content: ToolOutputFormatting.truncateMiddle(trimmed))
    case 1:
      return ToolResult(content: "No matches found.")
    default:
      let detail = result.standardError.isEmpty ? result.combinedOutput : result.standardError
      return ToolResult(
        content: "grep failed (exit code \(result.exitCode)): \(ToolOutputFormatting.truncateMiddle(detail)). Check that the pattern is a valid extended regular expression.",
        isError: true
      )
    }
  }
}
