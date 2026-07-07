import XCTest
@testable import AgentHarness

final class TranscriptTrimmerTests: XCTestCase {

  private func toolTurn(id: String, resultSize: Int, isError: Bool = false) -> [AgentMessage] {
    [
      .assistant(text: nil, toolCalls: [AgentToolCall(id: id, name: "Read", arguments: #"{"file_path":"a"}"#)]),
      .tool(callId: id, name: "Read", content: String(repeating: "x", count: resultSize), isError: isError),
    ]
  }

  func testFittingTranscriptIsUntouched() throws {
    let transcript = AgentTranscript(messages: [
      .system("sys"),
      .user([.text("hello")]),
      .assistant(text: "hi", toolCalls: []),
    ])
    let trimmed = try TranscriptTrimmer.trim(transcript, budgetTokens: 10_000)
    XCTAssertEqual(trimmed, transcript)
  }

  func testElidesOldestToolResultsBeforeDroppingAnything() throws {
    var messages: [AgentMessage] = [.system("system prompt")]
    messages += toolTurn(id: "t1", resultSize: 4_000)
    messages += [.user([.text("latest user question")])]
    messages += [.assistant(text: "answer", toolCalls: [])]
    let transcript = AgentTranscript(messages: messages)

    // Budget: everything minus the big tool result body fits comfortably.
    let fullEstimate = TokenEstimator.estimateTokens(in: transcript)
    let budget = fullEstimate - 500

    let trimmed = try TranscriptTrimmer.trim(transcript, budgetTokens: budget)
    XCTAssertEqual(trimmed.messages.count, transcript.messages.count, "elision must not drop messages")
    guard case .tool(_, _, let content, _) = trimmed.messages[2] else {
      return XCTFail("expected tool message at index 2")
    }
    XCTAssertEqual(content, TranscriptTrimmer.elisionMarker)
    assertTranscriptIsAPIValid(trimmed)
  }

  func testErrorToolResultsAreNotElided() throws {
    var messages: [AgentMessage] = [.system("s")]
    messages += toolTurn(id: "err", resultSize: 200, isError: true)
    messages += toolTurn(id: "big", resultSize: 4_000)
    messages += [.user([.text("latest")])]
    let transcript = AgentTranscript(messages: messages)
    let budget = TokenEstimator.estimateTokens(in: transcript) - 500

    let trimmed = try TranscriptTrimmer.trim(transcript, budgetTokens: budget)
    guard case .tool(_, _, let errContent, let isError) = trimmed.messages[2] else {
      return XCTFail("expected error tool message")
    }
    XCTAssertTrue(isError)
    XCTAssertNotEqual(errContent, TranscriptTrimmer.elisionMarker)
  }

  func testDropsWholeTurnGroupsWithoutOrphaningToolResults() throws {
    var messages: [AgentMessage] = [.system("system")]
    for turn in 0..<10 {
      messages += toolTurn(id: "t\(turn)", resultSize: 2_000)
    }
    messages += [.user([.text("final question")])]
    let transcript = AgentTranscript(messages: messages)

    // Small budget forces drops well past what elision saves.
    let budget = 1_200
    let trimmed = try TranscriptTrimmer.trim(transcript, budgetTokens: budget)

    XCTAssertLessThanOrEqual(TokenEstimator.estimateTokens(in: trimmed), budget)
    assertTranscriptIsAPIValid(trimmed)
    XCTAssertEqual(trimmed.messages.first, .system("system"))
    XCTAssertEqual(trimmed.messages.last, .user([.text("final question")]))
  }

  func testNeverDropsSystemOrLastUserAndThrowsWhenIrreducible() {
    let transcript = AgentTranscript(messages: [
      .system(String(repeating: "s", count: 2_000)),
      .user([.text(String(repeating: "u", count: 2_000))]),
    ])
    XCTAssertThrowsError(try TranscriptTrimmer.trim(transcript, budgetTokens: 100)) { error in
      guard case AgentHarnessError.contextWindowExceeded = error else {
        return XCTFail("expected contextWindowExceeded, got \(error)")
      }
    }
  }

  func testMessagesAfterLastUserAreProtected() throws {
    var messages: [AgentMessage] = [.system("s")]
    for turn in 0..<6 {
      messages += toolTurn(id: "old\(turn)", resultSize: 2_000)
    }
    messages += [.user([.text("current request")])]
    messages += toolTurn(id: "current", resultSize: 2_000)
    let transcript = AgentTranscript(messages: messages)

    let protectedTail = AgentTranscript(messages: Array(messages.suffix(3)))
    let budget = TokenEstimator.estimateTokens(in: protectedTail)
      + TokenEstimator.estimateTokens(in: AgentMessage.system("s")) + 50

    let trimmed = try TranscriptTrimmer.trim(transcript, budgetTokens: budget)
    // The turn after the last user message survives with full content.
    guard case .tool(let callId, _, let content, _) = trimmed.messages.last else {
      return XCTFail("expected trailing tool result")
    }
    XCTAssertEqual(callId, "current")
    XCTAssertNotEqual(content, TranscriptTrimmer.elisionMarker)
    assertTranscriptIsAPIValid(trimmed)
  }
}
