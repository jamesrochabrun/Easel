import Foundation
import XCTest
@testable import ClaudeCodeCore

final class MessageStoreTests: XCTestCase {
  @MainActor
  func testUpdateMessagePreservesOriginalOrderingMetadata() {
    let store = MessageStore()
    let messageID = UUID()
    let timestamp = Date(timeIntervalSince1970: 1_234)
    let taskGroupID = UUID()
    let message = ChatMessage(
      id: messageID,
      role: .assistant,
      content: "draft",
      timestamp: timestamp,
      isComplete: false,
      messageType: .text,
      toolUseID: "tool-1",
      wasCancelled: true,
      taskGroupId: taskGroupID,
      isTaskContainer: true
    )

    store.addMessage(message)
    store.updateMessage(id: messageID, content: "done", isComplete: true, isError: true)

    let updated = store.findMessage(id: messageID)
    XCTAssertEqual(updated?.content, "done")
    XCTAssertEqual(updated?.timestamp, timestamp)
    XCTAssertEqual(updated?.toolUseID, "tool-1")
    XCTAssertEqual(updated?.wasCancelled, true)
    XCTAssertEqual(updated?.taskGroupId, taskGroupID)
    XCTAssertEqual(updated?.isTaskContainer, true)
    XCTAssertEqual(updated?.isComplete, true)
    XCTAssertEqual(updated?.isError, true)
  }
}
