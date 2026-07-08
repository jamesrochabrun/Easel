import XCTest
@testable import AgentHarness

final class PseudoToolCallParserTests: XCTestCase {

  private let tools: Set<String> = ["LS", "Read", "Write", "Edit", "Bash"]

  func testBareJSONObjectWithArguments() throws {
    let result = try XCTUnwrap(
      PseudoToolCallParser.parse(
        text: #"{"name": "LS", "arguments": {"path": "."}}"#,
        knownToolNames: tools
      )
    )
    XCTAssertEqual(result.calls.count, 1)
    XCTAssertEqual(result.calls[0].name, "LS")
    XCTAssertEqual(try JSONValue(parsing: result.calls[0].arguments)["path"]?.stringValue, ".")
    XCTAssertNil(result.residualText, "whole-text payloads are consumed")
  }

  func testFencedBashBlockWithoutArguments() throws {
    // The exact real-world failure: qwen2.5-coder printing a ```bash block.
    let text = """
    To provide you with the project structure, I'll use the LS tool.
    ```bash
    {"name": "LS"}
    ```
    Once you have this information, please provide it.
    """
    let result = try XCTUnwrap(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
    XCTAssertEqual(result.calls.map(\.name), ["LS"])
    XCTAssertEqual(result.calls[0].arguments, "{}")
    let residual = try XCTUnwrap(result.residualText)
    XCTAssertTrue(residual.contains("project structure"))
    XCTAssertFalse(residual.contains("\"name\""))
  }

  func testParametersKeyVariant() throws {
    let result = try XCTUnwrap(
      PseudoToolCallParser.parse(
        text: #"{"name": "Read", "parameters": {"file_path": "index.html"}}"#,
        knownToolNames: tools
      )
    )
    XCTAssertEqual(try JSONValue(parsing: result.calls[0].arguments)["file_path"]?.stringValue, "index.html")
  }

  func testArrayOfCalls() throws {
    let text = #"[{"name": "Read", "arguments": {"file_path": "a"}}, {"name": "LS", "arguments": {}}]"#
    let result = try XCTUnwrap(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
    XCTAssertEqual(result.calls.map(\.name), ["Read", "LS"])
  }

  func testUnknownToolNameDoesNotConvert() {
    XCTAssertNil(
      PseudoToolCallParser.parse(
        text: #"{"name": "DeleteEverything", "arguments": {}}"#,
        knownToolNames: tools
      )
    )
  }

  func testEmbeddedJSONInProseIsExtractedAndProseRemains() throws {
    // The exact failure: qwen2.5-coder emits prose + a bare tool-call object.
    let text = #"""
    I will replace the content of the existing index.html with the "Hello World" page you requested.
    {"name": "Write", "parameters": {"content": "<html><body><h1>Hello</h1></body></html>", "file_path": "index.html"}}
    """#
    let result = try XCTUnwrap(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
    XCTAssertEqual(result.calls.map(\.name), ["Write"])
    let args = try JSONValue(parsing: result.calls[0].arguments)
    XCTAssertEqual(args["file_path"]?.stringValue, "index.html")
    let residual = try XCTUnwrap(result.residualText)
    XCTAssertTrue(residual.hasPrefix("I will replace"))
    XCTAssertFalse(residual.contains("\"name\""), "raw JSON must be stripped from the bubble")
  }

  func testBracesInsideStringValuesDoNotTerminateEarly() throws {
    let text = #"{"name": "Write", "arguments": {"content": "func f() { return {} }", "file_path": "a.swift"}}"#
    let result = try XCTUnwrap(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
    XCTAssertEqual(result.calls.count, 1)
    XCTAssertEqual(try JSONValue(parsing: result.calls[0].arguments)["content"]?.stringValue, "func f() { return {} }")
  }

  func testProseMentioningToolNameWithoutJSONIsNotConverted() {
    let text = "You could use the LS tool if you wanted, but I cannot run tools right now."
    XCTAssertNil(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
  }

  func testBareNoArgObjectBuriedInProseIsNotConverted() {
    // A no-argument object embedded in a sentence is ambiguous — don't fire.
    let text = #"You could call it like {"name": "LS"} if you wanted, but I won't."#
    XCTAssertNil(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
  }

  func testWholeMessageNoArgObjectStillConverts() throws {
    let result = try XCTUnwrap(PseudoToolCallParser.parse(text: #"{"name": "LS"}"#, knownToolNames: tools))
    XCTAssertEqual(result.calls.map(\.name), ["LS"])
    XCTAssertEqual(result.calls[0].arguments, "{}")
  }

  func testPlainProseIsNotConverted() {
    XCTAssertNil(PseudoToolCallParser.parse(text: "Here is your landing page plan.", knownToolNames: tools))
  }

  func testNonObjectArgumentsRejected() {
    XCTAssertNil(
      PseudoToolCallParser.parse(
        text: #"{"name": "LS", "arguments": "not-an-object"}"#,
        knownToolNames: tools
      )
    )
  }
}
