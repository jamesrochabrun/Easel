//
//  QueuedWebPreviewContextStoreTests.swift
//  EaselWebInspectorTests
//

import Testing
@testable import EaselWebInspector

@Suite("QueuedWebPreviewContextStore")
struct QueuedWebPreviewContextStoreTests {
  @Test("Empty store returns empty queue")
  func emptyStore() {
    let store = QueuedWebPreviewContextStore()
    let queue = store.queue(for: "session-1")
    #expect(queue.isEmpty)
    #expect(store.count(for: "session-1") == 0)
  }

  @Test("Append crop to session")
  func appendCropToSession() {
    var store = QueuedWebPreviewContextStore()
    store.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix",
      screenshotPath: nil,
      for: "session-1"
    )
    #expect(store.count(for: "session-1") == 1)
    #expect(store.count(for: "session-2") == 0)
  }

  @Test("Clear removes session queue")
  func clearSession() {
    var store = QueuedWebPreviewContextStore()
    store.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix",
      screenshotPath: nil,
      for: "session-1"
    )
    store.clear(for: "session-1")
    #expect(store.count(for: "session-1") == 0)
  }

  @Test("Transfer queue between sessions")
  func transferQueue() {
    var store = QueuedWebPreviewContextStore()
    store.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix",
      screenshotPath: nil,
      for: "old-session"
    )
    store.transferQueue(from: "old-session", to: "new-session")
    #expect(store.count(for: "old-session") == 0)
    #expect(store.count(for: "new-session") == 1)
  }

  @Test("Consume context prompt clears queue")
  func consumeContextPrompt() {
    var store = QueuedWebPreviewContextStore()
    store.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix layout",
      screenshotPath: nil,
      for: "session-1"
    )

    let prompt = store.consumeContextPrompt(for: "session-1")
    #expect(prompt != nil)
    #expect(store.count(for: "session-1") == 0)
  }
}
