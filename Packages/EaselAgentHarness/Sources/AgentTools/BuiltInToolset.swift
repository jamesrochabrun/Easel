import AgentHarness
import Foundation

/// Factory for the built-in workspace tool set.
///
/// Workstream B implements the tools (Bash, Read, Write, Edit, Glob, Grep, LS)
/// and returns them here, sharing one `FileReadRegistry` across the returned
/// set so Write/Edit can enforce read-before-modify.
public enum BuiltInToolset {
  public static func makeTools() -> [any AgentTool] {
    // Implementation lands in workstream B.
    []
  }
}
