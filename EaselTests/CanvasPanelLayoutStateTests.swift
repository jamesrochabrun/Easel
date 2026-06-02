//
//  CanvasPanelLayoutStateTests.swift
//  EaselTests
//

import Testing
@testable import Easel

struct CanvasPanelLayoutStateTests {
  @Test
  func commandShortcutCyclesThroughSidebarChatAndRestoreStates() {
    var state = CanvasPanelLayoutState.allPanels

    state.advanceCommandShortcutCycle()
    #expect(state == .sidebarCollapsed)
    #expect(!state.showsSidebar)
    #expect(state.showsChatPanel)

    state.advanceCommandShortcutCycle()
    #expect(state == .canvasOnly)
    #expect(!state.showsSidebar)
    #expect(!state.showsChatPanel)
    #expect(state.isCanvasFullWidth)

    state.advanceCommandShortcutCycle()
    #expect(state == .chatPanelRestored)
    #expect(!state.showsSidebar)
    #expect(state.showsChatPanel)

    state.advanceCommandShortcutCycle()
    #expect(state == .allPanels)
    #expect(state.showsSidebar)
    #expect(state.showsChatPanel)
  }

  @Test
  func fullWidthToggleRestoresAllPanels() {
    var state = CanvasPanelLayoutState.sidebarCollapsed

    state.toggleCanvasFullWidth()
    #expect(state == .canvasOnly)

    state.toggleCanvasFullWidth()
    #expect(state == .allPanels)
  }

  @Test
  func sidebarToggleRestoresAllPanelsFromRepeatedShortcutState() {
    var state = CanvasPanelLayoutState.chatPanelRestored

    state.toggleSidebar()

    #expect(state == .allPanels)
  }
}
