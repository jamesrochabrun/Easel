//
//  AppDelegateTests.swift
//  EaselTests
//

import AppKit
import Testing
@testable import Easel

@MainActor
struct AppDelegateTests {

  @Test
  func statusMenuOmitsOpenChatBarWhenFloatingChatBarIsDisabled() {
    let delegate = AppDelegate(isFloatingChatBarEnabled: false)

    let titles = delegate.buildStatusMenu().items.map(\.title)

    #expect(titles.contains("Open App Window"))
    #expect(!titles.contains("Open Chat Bar"))
    #expect(titles.contains("Quit Codex Design"))
  }

  @Test
  func statusMenuIncludesOpenChatBarWhenFloatingChatBarIsEnabled() {
    let delegate = AppDelegate(isFloatingChatBarEnabled: true)

    let titles = delegate.buildStatusMenu().items.map(\.title)

    #expect(titles.contains("Open App Window"))
    #expect(titles.contains("Open Chat Bar"))
    #expect(titles.contains("Quit Codex Design"))
  }
}
