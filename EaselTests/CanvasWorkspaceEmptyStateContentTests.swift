//
//  CanvasWorkspaceEmptyStateContentTests.swift
//  EaselTests
//

import Testing
@testable import Easel

struct CanvasWorkspaceEmptyStateContentTests {
  @Test
  func resolveReturnsNilWhenWorkingDirectoryIsActive() {
    let content = CanvasWorkspaceEmptyStateContent.resolve(
      currentWorkingDirectory: "/tmp/checkout",
      designCount: 0
    )

    #expect(content == nil)
  }

  @Test
  func resolveShowsNoDesignsWhenLibraryIsEmpty() {
    let content = CanvasWorkspaceEmptyStateContent.resolve(
      currentWorkingDirectory: nil,
      designCount: 0
    )

    #expect(content == .noDesigns)
  }

  @Test
  func resolveShowsNoSelectionWhenDesignsExist() {
    let content = CanvasWorkspaceEmptyStateContent.resolve(
      currentWorkingDirectory: nil,
      designCount: 3
    )

    #expect(content == .noSelection)
  }

  @Test
  func resolveTreatsWhitespaceWorkingDirectoryAsNoSelection() {
    let content = CanvasWorkspaceEmptyStateContent.resolve(
      currentWorkingDirectory: "   ",
      designCount: 1
    )

    #expect(content == .noSelection)
  }
}
