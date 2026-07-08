import XCTest
@testable import AgentHarness

final class ContractsTests: XCTestCase {

  // MARK: JSONValue

  func testJSONValueRoundTrip() throws {
    let value: JSONValue = [
      "type": "object",
      "properties": [
        "command": ["type": "string"],
        "timeout": ["type": "number"],
      ],
      "required": ["command"],
      "additionalProperties": false,
      "nullable": nil,
    ]
    let encoded = try value.encodedString()
    let decoded = try JSONValue(parsing: encoded)
    XCTAssertEqual(decoded, value)
    XCTAssertEqual(decoded["properties"]?["command"]?["type"]?.stringValue, "string")
  }

  func testJSONValueParsingInvalidThrows() {
    XCTAssertThrowsError(try JSONValue(parsing: "{not json"))
  }

  func testJSONValueIntAccessor() {
    XCTAssertEqual(JSONValue.number(42).intValue, 42)
    XCTAssertNil(JSONValue.number(42.5).intValue)
    XCTAssertNil(JSONValue.string("42").intValue)
  }

  // MARK: Transcript

  func testTranscriptCodableRoundTrip() throws {
    let transcript = AgentTranscript(messages: [
      .system("You are a coding agent."),
      .user([.text("hello"), .imageDataURL("data:image/jpeg;base64,AA==")]),
      .assistant(text: nil, toolCalls: [AgentToolCall(id: "call_1", name: "Read", arguments: "{\"file_path\":\"a.txt\"}")]),
      .tool(callId: "call_1", name: "Read", content: "contents", isError: false),
      .assistant(text: "done", toolCalls: []),
    ])
    let data = try JSONEncoder().encode(transcript)
    let decoded = try JSONDecoder().decode(AgentTranscript.self, from: data)
    XCTAssertEqual(decoded, transcript)
  }

  // MARK: EndpointProfile presets

  func testBuiltInPresetsHaveStableUniqueIds() {
    let presets = EndpointProfile.builtInPresets()
    XCTAssertEqual(Set(presets.map(\.id)).count, presets.count)
    XCTAssertTrue(presets.allSatisfy { $0.id.hasPrefix("preset-") })
    XCTAssertTrue(presets.contains { $0.kind == .ollamaNative })
    XCTAssertTrue(presets.contains { $0.kind == .mlxLocal })
    XCTAssertTrue(presets.contains { $0.kind == .openAICompatible })
  }

  func testPresetsCodableRoundTrip() throws {
    let presets = EndpointProfile.builtInPresets()
    let data = try JSONEncoder().encode(presets)
    let decoded = try JSONDecoder().decode([EndpointProfile].self, from: data)
    XCTAssertEqual(decoded, presets)
  }

  // MARK: PathConfinementPolicy

  private func makeWorkspace() throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("harness-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  func testPolicyAllowsPathsInsideRoot() throws {
    let root = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let policy = PathConfinementPolicy(root: root)

    let relative = try policy.resolveForRead("src/App.tsx")
    XCTAssertTrue(relative.path.hasPrefix(policy.root.path))

    let absolute = try policy.resolveForWrite(policy.root.appendingPathComponent("index.html").path)
    XCTAssertTrue(absolute.path.hasPrefix(policy.root.path))
  }

  func testPolicyRejectsEscapes() throws {
    let root = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let policy = PathConfinementPolicy(root: root)

    XCTAssertThrowsError(try policy.resolveForRead("../outside.txt"))
    XCTAssertThrowsError(try policy.resolveForRead("/etc/passwd"))
    XCTAssertThrowsError(try policy.resolveForWrite("a/../../outside.txt"))
  }

  func testPolicyRejectsSymlinkEscape() throws {
    let root = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let outside = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: outside) }

    let policy = PathConfinementPolicy(root: root)
    let link = root.appendingPathComponent("escape")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

    XCTAssertThrowsError(try policy.resolveForWrite("escape/newfile.txt"))
  }

  func testPolicyDeniesWritesToProtectedSubpath() throws {
    let root = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let policy = PathConfinementPolicy(root: root)

    XCTAssertThrowsError(try policy.resolveForWrite("resources/codebase-references/ref.swift")) { error in
      guard case PathConfinementPolicy.Violation.writeDenied = error else {
        return XCTFail("Expected writeDenied, got \(error)")
      }
    }
    // Reading reference material stays allowed.
    XCTAssertNoThrow(try policy.resolveForRead("resources/codebase-references/ref.swift"))
    // Sibling writes stay allowed.
    XCTAssertNoThrow(try policy.resolveForWrite("resources/design-system/DESIGN.md"))
  }
}
