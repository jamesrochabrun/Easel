//
//  WebPreviewScrollRestorationCoordinatorTests.swift
//  EaselWebInspectorTests
//

import Foundation
import Testing
@testable import EaselWebInspector

@Suite("WebPreviewScrollRestorationCoordinator")
struct WebPreviewScrollRestorationCoordinatorTests {
  @Test("Initial state has no tokens")
  func initialState() {
    let coordinator = WebPreviewScrollRestorationCoordinator()
    #expect(coordinator.effectiveReloadToken == nil)
    #expect(coordinator.pendingRequestedReloadToken == nil)
    #expect(coordinator.pendingScrollPosition == nil)
    #expect(!coordinator.isCapturingScrollPosition)
    #expect(!coordinator.suppressesSelectorRestore)
  }

  @Test("Queue reload sets pending token")
  func queueReload() {
    var coordinator = WebPreviewScrollRestorationCoordinator()
    let token = UUID()
    coordinator.queueReload(token: token)
    #expect(coordinator.pendingRequestedReloadToken == token)
  }

  @Test("Begin capture starts capturing")
  func beginCapture() {
    var coordinator = WebPreviewScrollRestorationCoordinator()
    let token = UUID()
    coordinator.queueReload(token: token)
    let started = coordinator.beginCaptureIfNeeded()
    #expect(started)
    #expect(coordinator.isCapturingScrollPosition)
  }

  @Test("Finish capture produces effective token")
  func finishCapture() {
    var coordinator = WebPreviewScrollRestorationCoordinator()
    let token = UUID()
    coordinator.queueReload(token: token)
    _ = coordinator.beginCaptureIfNeeded()

    let scrollPos = WebPreviewScrollPosition(x: 0, y: 100)
    let effectiveToken = coordinator.finishCapture(with: scrollPos)
    #expect(effectiveToken == token)
    #expect(coordinator.effectiveReloadToken == token)
    #expect(coordinator.suppressesSelectorRestore)
  }

  @Test("Consume pending scroll position")
  func consumeScrollPosition() {
    var coordinator = WebPreviewScrollRestorationCoordinator()
    let token = UUID()
    coordinator.queueReload(token: token)
    _ = coordinator.beginCaptureIfNeeded()

    let scrollPos = WebPreviewScrollPosition(x: 50, y: 200)
    _ = coordinator.finishCapture(with: scrollPos)

    let consumed = coordinator.consumePendingScrollPosition()
    #expect(consumed?.x == 50)
    #expect(consumed?.y == 200)
    #expect(!coordinator.suppressesSelectorRestore)

    let secondConsume = coordinator.consumePendingScrollPosition()
    #expect(secondConsume == nil)
  }

  @Test("Reset clears all state")
  func reset() {
    var coordinator = WebPreviewScrollRestorationCoordinator()
    let token = UUID()
    coordinator.queueReload(token: token)
    _ = coordinator.beginCaptureIfNeeded()
    _ = coordinator.finishCapture(with: WebPreviewScrollPosition(x: 0, y: 0))

    let resetToken = UUID()
    coordinator.reset(to: resetToken)
    #expect(coordinator.effectiveReloadToken == resetToken)
    #expect(coordinator.pendingRequestedReloadToken == nil)
    #expect(coordinator.pendingScrollPosition == nil)
    #expect(!coordinator.isCapturingScrollPosition)
    #expect(!coordinator.suppressesSelectorRestore)
  }
}
