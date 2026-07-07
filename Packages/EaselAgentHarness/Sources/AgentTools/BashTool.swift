import AgentHarness
import Foundation

/// Executes shell commands inside the project working directory.
public struct BashTool: AgentTool {

  public let name = "Bash"

  public let description = """
    Executes a bash command in the project working directory and returns its \
    combined stdout and stderr. Use for builds, package managers, git, and \
    other shell work. Do not use it to read or modify files — use the Read, \
    Write, Edit, Glob, and Grep tools for that. Long output is truncated in \
    the middle. A non-zero exit code is reported as an error together with \
    the output. Provide `timeout` in milliseconds for long-running commands \
    (default 120000, max 600000); the command is killed when it expires.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "command": [
        "type": "string",
        "description": "The bash command to execute.",
      ],
      "timeout": [
        "type": "number",
        "description": "Optional timeout in milliseconds (default 120000, max 600000).",
      ],
    ],
    "required": ["command"],
  ]

  public let isReadOnly = false

  static let defaultTimeoutMilliseconds = 120_000
  static let maximumTimeoutMilliseconds = 600_000

  public init() {}

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let command = arguments["command"]?.stringValue, !command.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'command'. Provide the bash command to run as a string.",
        isError: true
      )
    }

    let requestedTimeout = arguments["timeout"]?.intValue ?? Self.defaultTimeoutMilliseconds
    let timeoutMilliseconds = min(max(requestedTimeout, 1), Self.maximumTimeoutMilliseconds)

    let result: ProcessRunResult
    do {
      result = try await ProcessRunner.run(
        executablePath: "/bin/bash",
        arguments: ["-lc", command],
        workingDirectory: context.workingDirectory,
        environmentOverrides: context.environment,
        timeoutMilliseconds: timeoutMilliseconds
      )
    } catch {
      return ToolResult(
        content: "Failed to launch the command: \(error.localizedDescription)",
        isError: true
      )
    }

    let output = ToolOutputFormatting.truncateMiddle(result.combinedOutput)

    if result.timedOut {
      var content = "Command timed out after \(timeoutMilliseconds)ms and was killed."
      if !output.isEmpty {
        content += "\nPartial output:\n\(output)"
      }
      return ToolResult(content: content, isError: true)
    }

    if result.exitCode != 0 {
      var content = "Command failed with exit code \(result.exitCode)."
      content += output.isEmpty ? "\n(no output)" : "\n\(output)"
      return ToolResult(content: content, isError: true)
    }

    return ToolResult(content: output.isEmpty ? "(no output)" : output)
  }
}
