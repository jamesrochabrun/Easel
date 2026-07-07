import XCTest
@testable import AgentHarness

final class PseudoToolCallParserTests: XCTestCase {

  private let tools: Set<String> = ["LS", "Read", "Edit", "Bash"]

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

  func testProseMentioningJSONIsNotConverted() {
    let text = #"You could call it like {"name": "LS"} if you wanted, but I cannot run tools."#
    XCTAssertNil(PseudoToolCallParser.parse(text: text, knownToolNames: tools))
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
