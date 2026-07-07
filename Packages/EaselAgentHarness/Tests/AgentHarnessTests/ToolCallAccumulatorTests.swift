import XCTest
@testable import AgentHarness

final class ToolCallAccumulatorTests: XCTestCase {

  func testFragmentedArgumentsReassembleByteExact() {
    let full = #"{"file_path":"src/Ünïcode — path.tsx","content":"line1\n\"quoted\" \\ backslash 🚀"}"#
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "call_abc", name: "Edit", fragment: "")
    // 3-char chunks split escapes, multi-byte characters, and emoji mid-sequence.
    var remaining = Substring(full)
    while !remaining.isEmpty {
      let chunk = String(remaining.prefix(3))
      remaining = remaining.dropFirst(3)
      accumulator.ingest(index: 0, id: nil, name: nil, fragment: chunk)
    }

    let calls = accumulator.finalize()
    XCTAssertEqual(calls.count, 1)
    XCTAssertEqual(calls[0].id, "call_abc")
    XCTAssertEqual(calls[0].name, "Edit")
    XCTAssertEqual(calls[0].arguments, full)
  }

  func testInterleavedParallelCallsSeparateByIndex() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "a", name: "Read", fragment: #"{"file"#)
    accumulator.ingest(index: 1, id: "b", name: "Grep", fragment: #"{"pat"#)
    accumulator.ingest(index: 0, id: nil, name: nil, fragment: #"_path":"x"}"#)
    accumulator.ingest(index: 1, id: nil, name: nil, fragment: #"tern":"y"}"#)

    let calls = accumulator.finalize()
    XCTAssertEqual(calls.map(\.id), ["a", "b"])
    XCTAssertEqual(calls.map(\.name), ["Read", "Grep"])
    XCTAssertEqual(calls[0].arguments, #"{"file_path":"x"}"#)
    XCTAssertEqual(calls[1].arguments, #"{"pattern":"y"}"#)
  }

  func testWholeCallInOneChunk() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "x", name: "Bash", fragment: #"{"command":"ls"}"#)
    let calls = accumulator.finalize()
    XCTAssertEqual(calls[0].arguments, #"{"command":"ls"}"#)
  }

  func testIndexGapsSortByIndex() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 5, id: "late", name: "B", fragment: "{}")
    accumulator.ingest(index: 0, id: "early", name: "A", fragment: "{}")
    XCTAssertEqual(accumulator.finalize().map(\.id), ["early", "late"])
  }

  func testMissingIdIsSynthesizedWithIndexPrefix() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 2, id: nil, name: "Read", fragment: "{}")
    let call = accumulator.finalize()[0]
    XCTAssertTrue(call.id.hasPrefix("call_2_"), "got \(call.id)")
  }

  func testIdNeverOverwritten() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "first", name: "Read", fragment: "{")
    accumulator.ingest(index: 0, id: "second", name: nil, fragment: "}")
    XCTAssertEqual(accumulator.finalize()[0].id, "first")
  }

  func testNameFragmentsConcatenate() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "a", name: "Multi", fragment: "")
    accumulator.ingest(index: 0, id: nil, name: "Edit", fragment: "{}")
    XCTAssertEqual(accumulator.finalize()[0].name, "MultiEdit")
  }

  func testEmptyArgumentsDefaultToEmptyObject() {
    var accumulator = ToolCallAccumulator()
    accumulator.ingest(index: 0, id: "a", name: "LS", fragment: "")
    XCTAssertEqual(accumulator.finalize()[0].arguments, "{}")
  }

  func testEmptyAccumulatorFinalizesToNothing() {
    XCTAssertTrue(ToolCallAccumulator().finalize().isEmpty)
    XCTAssertTrue(ToolCallAccumulator().isEmpty)
  }
}
