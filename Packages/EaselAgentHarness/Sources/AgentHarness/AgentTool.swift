import Foundation

/// The outcome of executing a tool.
///
/// Contract: expected failures (file not found, non-unique edit match,
/// non-zero exit code) are returned as `isError: true` results so the model
/// can read the message and self-correct. `AgentTool.execute` throws only for
/// infrastructure failures the model cannot act on.
public struct ToolResult: Sendable, Equatable {
  public var content: String
  public var isError: Bool
  /// Hints for UI presentation (e.g. ["file_path": "src/App.tsx"]).
  public var uiHints: [String: String]

  public init(content: String, isError: Bool = false, uiHints: [String: String] = [:]) {
    self.content = content
    self.isError = isError
    self.uiHints = uiHints
  }
}

/// Execution environment handed to every tool call.
public struct ToolExecutionContext: Sendable {
  public let workingDirectory: URL
  public let pathPolicy: PathConfinementPolicy
  public let environment: [String: String]

  public init(
    workingDirectory: URL,
    pathPolicy: PathConfinementPolicy,
    environment: [String: String] = [:]
  ) {
    self.workingDirectory = workingDirectory
    self.pathPolicy = pathPolicy
    self.environment = environment
  }
}

/// A tool the harness offers to the model.
///
/// Names deliberately mirror Claude Code's tool set (`Bash`, `Read`, `Write`,
/// `Edit`, `Glob`, `Grep`, `LS`) so Easel's existing tool-card UI renders them
/// without changes.
public protocol AgentTool: Sendable {
  var name: String { get }
  /// Sent to the model; write it for the model, not for humans.
  var description: String { get }
  /// JSON Schema for the arguments object.
  var parametersJSONSchema: JSONValue { get }
  /// Read-only tools may execute concurrently; mutating tools run serially.
  var isReadOnly: Bool { get }

  func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult
}
