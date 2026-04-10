//
//  WebPreviewContextQueueTests.swift
//  EaselWebInspectorTests
//

import Testing
@testable import EaselWebInspector

@Suite("WebPreviewContextQueue")
struct WebPreviewContextQueueTests {
  @Test("Empty queue returns nil prompt")
  func emptyQueueReturnsNilPrompt() {
    let queue = WebPreviewContextQueue()
    #expect(queue.isEmpty)
    #expect(queue.count == 0)
    #expect(queue.composedContextPrompt() == nil)
  }

  @Test("Append and remove items")
  func appendAndRemove() {
    var queue = WebPreviewContextQueue()

    queue.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix layout",
      screenshotPath: nil
    )
    #expect(queue.count == 1)

    let itemId = queue.items.first!.id
    queue.remove(id: itemId)
    #expect(queue.isEmpty)
  }

  @Test("Clear removes all items")
  func clearRemovesAll() {
    var queue = WebPreviewContextQueue()

    queue.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix",
      screenshotPath: nil
    )
    queue.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 200, height: 200),
      elements: [],
      instruction: "Update",
      screenshotPath: nil
    )
    #expect(queue.count == 2)

    queue.clear()
    #expect(queue.isEmpty)
  }

  @Test("Screenshot paths from crop items")
  func screenshotPaths() {
    var queue = WebPreviewContextQueue()

    queue.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 100, height: 100),
      elements: [],
      instruction: "Fix",
      screenshotPath: "/tmp/screenshot1.png"
    )
    queue.appendCrop(
      cropRect: .init(x: 0, y: 0, width: 200, height: 200),
      elements: [],
      instruction: "Update",
      screenshotPath: nil
    )

    let paths = queue.screenshotPaths()
    #expect(paths == ["/tmp/screenshot1.png"])
  }
}
