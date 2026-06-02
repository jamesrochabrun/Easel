//
//  CanvasPanelLayoutState.swift
//  Easel
//

enum CanvasPanelLayoutState: Equatable {
  case allPanels
  case sidebarCollapsed
  case canvasOnly
  case chatPanelRestored

  var showsSidebar: Bool {
    self == .allPanels
  }

  var showsChatPanel: Bool {
    self != .canvasOnly
  }

  var isCanvasFullWidth: Bool {
    self == .canvasOnly
  }

  mutating func advanceCommandShortcutCycle() {
    self = nextCommandShortcutState
  }

  mutating func toggleSidebar() {
    switch self {
    case .allPanels:
      self = .sidebarCollapsed
    case .sidebarCollapsed, .chatPanelRestored, .canvasOnly:
      self = .allPanels
    }
  }

  mutating func toggleCanvasFullWidth() {
    self = isCanvasFullWidth ? .allPanels : .canvasOnly
  }

  private var nextCommandShortcutState: CanvasPanelLayoutState {
    switch self {
    case .allPanels:
      return .sidebarCollapsed
    case .sidebarCollapsed:
      return .canvasOnly
    case .canvasOnly:
      return .chatPanelRestored
    case .chatPanelRestored:
      return .allPanels
    }
  }
}
