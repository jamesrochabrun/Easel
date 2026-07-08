import AgentHarness
import Foundation

/// Factory for the built-in workspace tool set.
///
/// Returns the seven built-in tools (Bash, Read, Write, Edit, Glob, Grep, LS)
/// sharing a single `FileReadRegistry` so Write/Edit can enforce
/// read-before-modify and stale-read detection against the same read history.
public enum BuiltInToolset {
  public static func makeTools() -> [any AgentTool] {
    let registry = FileReadRegistry()
    return [
      BashTool(),
      ReadTool(registry: registry),
      WriteTool(registry: registry),
      EditTool(registry: registry),
      GlobTool(),
      GrepTool(),
      LSTool(),
    ]
  }
}
