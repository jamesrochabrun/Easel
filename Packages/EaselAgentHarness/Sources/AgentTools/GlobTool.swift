import AgentHarness
import Foundation

/// Finds files matching a glob pattern, newest first.
public struct GlobTool: AgentTool {

  public let name = "Glob"

  public let description = """
    Finds files whose path matches a glob pattern (e.g. "*.swift", \
    "src/**/*.ts") and returns their absolute paths sorted by modification \
    time, newest first. Matching is against paths relative to the search \
    directory. Pass `path` to search a subdirectory; it defaults to the \
    working directory. Common build and dependency directories (.git, \
    node_modules, .build, dist) are skipped. Results are capped at 100 \
    files. Use this to locate files by name; use Grep to search file \
    contents.
    """

  public let parametersJSONSchema: JSONValue = [
    "type": "object",
    "properties": [
      "pattern": [
        "type": "string",
        "description": "Glob pattern matched against paths relative to the search directory, e.g. \"**/*.swift\".",
      ],
      "path": [
        "type": "string",
        "description": "Directory to search. Defaults to the working directory.",
      ],
    ],
    "required": ["pattern"],
  ]

  public let isReadOnly = true

  static let maximumResults = 100
  static let skippedDirectoryNames: Set<String> = [".git", "node_modules", ".build", "dist"]

  public init() {}

  public func execute(arguments: JSONValue, context: ToolExecutionContext) async throws -> ToolResult {
    guard let pattern = arguments["pattern"]?.stringValue, !pattern.isEmpty else {
      return ToolResult(
        content: "Missing required parameter 'pattern'. Provide a glob pattern like \"**/*.swift\".",
        isError: true
      )
    }

    let base: URL
    do {
      base = try context.pathPolicy.resolveForRead(arguments["path"]?.stringValue ?? ".")
    } catch {
      return ToolResult(content: error.localizedDescription, isError: true)
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: base.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      return ToolResult(
        content: "Search path is not an existing directory: \(base.path). Pass an existing directory or omit 'path' to search the working directory.",
        isError: true
      )
    }

    let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey]
    guard let enumerator = fileManager.enumerator(
      at: base,
      includingPropertiesForKeys: keys,
      options: []
    ) else {
      return ToolResult(content: "Could not enumerate directory: \(base.path)", isError: true)
    }

    let basePrefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
    var matches: [(path: String, modified: Date)] = []

    while let entry = enumerator.nextObject() as? URL {
      let values = try? entry.resourceValues(forKeys: Set(keys))
      if values?.isDirectory == true {
        if Self.skippedDirectoryNames.contains(entry.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }
      guard values?.isRegularFile == true else { continue }

      let standardized = entry.standardizedFileURL.path
      guard standardized.hasPrefix(basePrefix) else { continue }
      let relative = String(standardized.dropFirst(basePrefix.count))
      guard Self.matches(pattern: pattern, relativePath: relative) else { continue }
      matches.append((standardized, values?.contentModificationDate ?? .distantPast))
    }

    guard !matches.isEmpty else {
      return ToolResult(content: "No files found matching \"\(pattern)\" in \(base.path).")
    }

    matches.sort { $0.modified > $1.modified }
    let capped = matches.prefix(Self.maximumResults)
    var content = capped.map(\.path).joined(separator: "\n")
    if matches.count > Self.maximumResults {
      content += "\n… [\(matches.count - Self.maximumResults) more matches not shown; narrow the pattern or path]"
    }
    return ToolResult(content: content)
  }

  /// fnmatch-based matching. `*` and `?` may cross path separators (so
  /// `**/*.swift` matches deeply nested files); a leading `**/` also matches
  /// files at the top level of the search directory.
  static func matches(pattern: String, relativePath: String) -> Bool {
    if fnmatch(pattern, relativePath, 0) == 0 {
      return true
    }
    if pattern.hasPrefix("**/"), fnmatch(String(pattern.dropFirst(3)), relativePath, 0) == 0 {
      return true
    }
    return false
  }
}
