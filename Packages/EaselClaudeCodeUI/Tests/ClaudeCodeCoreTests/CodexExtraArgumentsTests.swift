import XCTest
@testable import ClaudeCodeCore

final class CodexExtraArgumentsTests: XCTestCase {

  // MARK: - parseArgumentString

  func testParsesSimpleArguments() {
    XCTAssertEqual(
      CodexChatRuntime.parseArgumentString("--api-mode enterprise"),
      ["--api-mode", "enterprise"]
    )
  }

  func testEmptyStringYieldsNoArguments() {
    XCTAssertEqual(CodexChatRuntime.parseArgumentString(""), [])
    XCTAssertEqual(CodexChatRuntime.parseArgumentString("    "), [])
  }

  func testCollapsesRepeatedWhitespace() {
    XCTAssertEqual(
      CodexChatRuntime.parseArgumentString("  --a    --b\t--c "),
      ["--a", "--b", "--c"]
    )
  }

  func testHonorsDoubleQuotedValuesWithSpaces() {
    XCTAssertEqual(
      CodexChatRuntime.parseArgumentString("--name \"hello world\""),
      ["--name", "hello world"]
    )
  }

  func testHonorsSingleQuotedValues() {
    XCTAssertEqual(
      CodexChatRuntime.parseArgumentString("--path '/tmp/a b/c'"),
      ["--path", "/tmp/a b/c"]
    )
  }

  func testHonorsBackslashEscape() {
    XCTAssertEqual(
      CodexChatRuntime.parseArgumentString("a\\ b c"),
      ["a b", "c"]
    )
  }

  // MARK: - extraArguments → extraFlags

  @MainActor
  func testExtraArgumentsAreAppendedToFlags() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      modelIdentifier: nil,
      extraArguments: ["--api-mode", "enterprise"],
      configOverrides: [:]
    )

    XCTAssertTrue(options.extraFlags.contains("--api-mode"))
    XCTAssertTrue(options.extraFlags.contains("enterprise"))
  }

  @MainActor
  func testNoExtraArgumentsLeavesFlagsEmpty() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/easel",
      modelIdentifier: nil,
      extraArguments: [],
      configOverrides: [:]
    )

    XCTAssertTrue(options.extraFlags.isEmpty)
  }

  @MainActor
  func testExtraArgumentsAppendedOnResume() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: false,
      currentSessionId: "thread-id",
      workingDirectory: "/tmp/easel",
      modelIdentifier: nil,
      extraArguments: ["--verbose"],
      configOverrides: [:]
    )

    XCTAssertTrue(options.extraFlags.contains("--verbose"))
  }
}
