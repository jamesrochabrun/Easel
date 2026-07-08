import Foundation
import XCTest
import AgentHarness
@testable import AgentTools

final class BuiltInToolsTests: XCTestCase {

  private var root: URL!
  private var context: ToolExecutionContext!
  private var registry: FileReadRegistry!

  override func setUpWithError() throws {
    root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-tools-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    context = ToolExecutionContext(workingDirectory: root, pathPolicy: PathConfinementPolicy(root: root))
    registry = FileReadRegistry()
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  private func args(_ value: JSONValue) -> JSONValue { value }

  // MARK: - Write / Read / Edit round trip

  func testWriteReadEditRoundTrip() async throws {
    let write = WriteTool(registry: registry)
    let read = ReadTool(registry: registry)
    let edit = EditTool(registry: registry)

    let created = try await write.execute(
      arguments: ["file_path": "src/App.tsx", "content": "const a = 1\nconst b = 2\n"],
      context: context
    )
    XCTAssertFalse(created.isError, created.content)

    let readResult = try await read.execute(arguments: ["file_path": "src/App.tsx"], context: context)
    XCTAssertFalse(readResult.isError)
    XCTAssertTrue(readResult.content.contains("const a = 1"))
    XCTAssertTrue(readResult.content.contains("1\t"), "expected cat -n style line numbers")

    let edited = try await edit.execute(
      arguments: ["file_path": "src/App.tsx", "old_string": "const a = 1", "new_string": "const a = 42"],
      context: context
    )
    XCTAssertFalse(edited.isError, edited.content)

    let onDisk = try String(contentsOf: root.appendingPathComponent("src/App.tsx"), encoding: .utf8)
    XCTAssertTrue(onDisk.contains("const a = 42"))
  }

  // MARK: - Read-before-modify enforcement

  func testWriteToExistingUnreadFileIsDenied() async throws {
    let path = root.appendingPathComponent("existing.txt")
    try "original".write(to: path, atomically: true, encoding: .utf8)

    let write = WriteTool(registry: registry)
    let result = try await write.execute(
      arguments: ["file_path": "existing.txt", "content": "clobbered"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.lowercased().contains("read"), result.content)
    XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "original")
  }

  func testEditWithoutPriorReadIsDenied() async throws {
    try "hello".write(to: root.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    let edit = EditTool(registry: registry)
    let result = try await edit.execute(
      arguments: ["file_path": "a.txt", "old_string": "hello", "new_string": "bye"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("Read the file first"), result.content)
  }

  func testEditDetectsStaleRead() async throws {
    let path = root.appendingPathComponent("stale.txt")
    try "v1".write(to: path, atomically: true, encoding: .utf8)

    let read = ReadTool(registry: registry)
    _ = try await read.execute(arguments: ["file_path": "stale.txt"], context: context)

    // Simulate an external modification with a guaranteed-different mtime.
    try FileManager.default.setAttributes(
      [.modificationDate: Date().addingTimeInterval(60)],
      ofItemAtPath: path.path
    )

    let edit = EditTool(registry: registry)
    let result = try await edit.execute(
      arguments: ["file_path": "stale.txt", "old_string": "v1", "new_string": "v2"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("modified on disk"), result.content)
  }

  func testEditUniquenessErrorThenReplaceAll() async throws {
    let path = root.appendingPathComponent("dup.txt")
    try "x = 1\nx = 1\n".write(to: path, atomically: true, encoding: .utf8)
    let read = ReadTool(registry: registry)
    _ = try await read.execute(arguments: ["file_path": "dup.txt"], context: context)

    let edit = EditTool(registry: registry)
    let ambiguous = try await edit.execute(
      arguments: ["file_path": "dup.txt", "old_string": "x = 1", "new_string": "x = 2"],
      context: context
    )
    XCTAssertTrue(ambiguous.isError)
    XCTAssertTrue(ambiguous.content.contains("2 places"), ambiguous.content)

    let replaced = try await edit.execute(
      arguments: ["file_path": "dup.txt", "old_string": "x = 1", "new_string": "x = 2", "replace_all": true],
      context: context
    )
    XCTAssertFalse(replaced.isError, replaced.content)
    XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "x = 2\nx = 2\n")
  }

  func testEditOldStringNotFoundIsInstructive() async throws {
    try "actual content".write(to: root.appendingPathComponent("m.txt"), atomically: true, encoding: .utf8)
    _ = try await ReadTool(registry: registry).execute(arguments: ["file_path": "m.txt"], context: context)

    let result = try await EditTool(registry: registry).execute(
      arguments: ["file_path": "m.txt", "old_string": "does not exist", "new_string": "x"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("not found"), result.content)
  }

  // MARK: - Path confinement

  func testPathEscapesReturnErrorResultsNotThrows() async throws {
    let read = ReadTool(registry: registry)
    let escaped = try await read.execute(arguments: ["file_path": "../outside.txt"], context: context)
    XCTAssertTrue(escaped.isError)
    XCTAssertTrue(escaped.content.contains("outside the project workspace"), escaped.content)

    let absolute = try await WriteTool(registry: registry).execute(
      arguments: ["file_path": "/etc/hosts-copy", "content": "x"],
      context: context
    )
    XCTAssertTrue(absolute.isError)
  }

  func testCodebaseReferencesWriteDenied() async throws {
    let result = try await WriteTool(registry: registry).execute(
      arguments: ["file_path": "resources/codebase-references/ref.swift", "content": "x"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("read-only"), result.content)
  }

  // MARK: - Bash

  func testBashHappyPath() async throws {
    let result = try await BashTool().execute(
      arguments: ["command": "echo hello-from-bash"],
      context: context
    )
    XCTAssertFalse(result.isError, result.content)
    XCTAssertTrue(result.content.contains("hello-from-bash"))
  }

  func testBashRunsInWorkingDirectory() async throws {
    try "marker".write(to: root.appendingPathComponent("marker.txt"), atomically: true, encoding: .utf8)
    let result = try await BashTool().execute(arguments: ["command": "ls"], context: context)
    XCTAssertTrue(result.content.contains("marker.txt"), result.content)
  }

  func testBashNonZeroExitIsErrorWithCode() async throws {
    let result = try await BashTool().execute(
      arguments: ["command": "echo failing >&2; exit 3"],
      context: context
    )
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("exit code 3"), result.content)
    XCTAssertTrue(result.content.contains("failing"), result.content)
  }

  func testBashTimeoutKillsPromptly() async throws {
    let start = ContinuousClock.now
    let result = try await BashTool().execute(
      arguments: ["command": "sleep 30", "timeout": 400],
      context: context
    )
    let elapsed = start.duration(to: .now)
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("timed out"), result.content)
    XCTAssertLessThan(elapsed, .seconds(10), "timed-out command must not run to completion")
  }

  func testBashLongOutputIsTruncatedInTheMiddle() async throws {
    let result = try await BashTool().execute(
      arguments: ["command": "head -c 60000 /dev/zero | tr '\\0' 'a'"],
      context: context
    )
    XCTAssertFalse(result.isError, result.content)
    XCTAssertTrue(result.content.contains("output truncated"), "expected elision marker")
    XCTAssertLessThan(result.content.count, 40_000)
  }

  func testBashMissingCommandParameter() async throws {
    let result = try await BashTool().execute(arguments: [:], context: context)
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.content.contains("command"), result.content)
  }

  // MARK: - Glob / Grep / LS

  func testGlobMatchesPattern() async throws {
    try "a".write(to: root.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    try "b".write(to: root.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)
    try "c".write(to: root.appendingPathComponent("three.md"), atomically: true, encoding: .utf8)

    let result = try await GlobTool().execute(arguments: ["pattern": "*.txt"], context: context)
    XCTAssertFalse(result.isError, result.content)
    XCTAssertTrue(result.content.contains("one.txt"))
    XCTAssertTrue(result.content.contains("two.txt"))
    XCTAssertFalse(result.content.contains("three.md"))
  }

  func testGrepContentAndCountModes() async throws {
    try "needle here\nplain line\nanother needle\n"
      .write(to: root.appendingPathComponent("hay.txt"), atomically: true, encoding: .utf8)

    let content = try await GrepTool().execute(arguments: ["pattern": "needle"], context: context)
    XCTAssertFalse(content.isError, content.content)
    XCTAssertTrue(content.content.contains("needle here"))

    let files = try await GrepTool().execute(
      arguments: ["pattern": "needle", "output_mode": "files_with_matches"],
      context: context
    )
    XCTAssertTrue(files.content.contains("hay.txt"))

    let noMatch = try await GrepTool().execute(arguments: ["pattern": "zzz-nope"], context: context)
    XCTAssertFalse(noMatch.isError, "no matches must not be an error")
    XCTAssertTrue(noMatch.content.contains("No matches"), noMatch.content)
  }

  func testLSListsDirectory() async throws {
    try FileManager.default.createDirectory(at: root.appendingPathComponent("subdir"), withIntermediateDirectories: true)
    try "x".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

    let result = try await LSTool().execute(arguments: [:], context: context)
    XCTAssertFalse(result.isError, result.content)
    XCTAssertTrue(result.content.contains("subdir"))
    XCTAssertTrue(result.content.contains("file.txt"))
  }

  // MARK: - Read details

  func testReadMissingFileIsError() async throws {
    let result = try await ReadTool(registry: registry).execute(
      arguments: ["file_path": "nope.txt"],
      context: context
    )
    XCTAssertTrue(result.isError)
  }

  func testReadOffsetAndLimit() async throws {
    let lines = (1...50).map { "line \($0)" }.joined(separator: "\n")
    try lines.write(to: root.appendingPathComponent("long.txt"), atomically: true, encoding: .utf8)

    let result = try await ReadTool(registry: registry).execute(
      arguments: ["file_path": "long.txt", "offset": 10, "limit": 5],
      context: context
    )
    XCTAssertFalse(result.isError, result.content)
    XCTAssertTrue(result.content.contains("line 10") || result.content.contains("line 11"), result.content)
    XCTAssertFalse(result.content.contains("line 30"))
  }

  // MARK: - Toolset

  func testToolsetSharesOneRegistryAcrossReadAndEdit() async throws {
    let tools = BuiltInToolset.makeTools()
    XCTAssertEqual(tools.count, 7)
    XCTAssertEqual(
      Set(tools.map(\.name)),
      ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "LS"]
    )

    try "shared".write(to: root.appendingPathComponent("s.txt"), atomically: true, encoding: .utf8)
    let read = tools.first { $0.name == "Read" }!
    let edit = tools.first { $0.name == "Edit" }!

    _ = try await read.execute(arguments: ["file_path": "s.txt"], context: context)
    let result = try await edit.execute(
      arguments: ["file_path": "s.txt", "old_string": "shared", "new_string": "linked"],
      context: context
    )
    XCTAssertFalse(result.isError, "Edit must see the Read recorded through the shared registry: \(result.content)")
  }

  func testReadOnlyFlags() {
    let tools = BuiltInToolset.makeTools()
    let readOnly = Set(tools.filter(\.isReadOnly).map(\.name))
    XCTAssertEqual(readOnly, ["Read", "Glob", "Grep", "LS"])
  }
}
