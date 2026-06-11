//
//  AppDelegate.swift
//  Easel
//

import AppKit
import EaselChat
import EaselKit
import EaselServerManager

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowController: WindowController?
  private var statusItem: NSStatusItem?
  private let isFloatingChatBarEnabled: Bool
  private let softwareUpdater: SoftwareUpdating
  let appState = AppState()
  let chatService = ChatService()
  var serverManager: ProjectServerManager?

  override convenience init() {
    self.init(isFloatingChatBarEnabled: false)
  }

  init(
    isFloatingChatBarEnabled: Bool,
    softwareUpdater: SoftwareUpdating? = nil
  ) {
    self.isFloatingChatBarEnabled = isFloatingChatBarEnabled
    self.softwareUpdater = softwareUpdater ?? SparkleSoftwareUpdater()
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    appState.openCanvas()
    let controller = WindowController(
      appState: appState,
      chatService: chatService,
      isFloatingChatBarEnabled: isFloatingChatBarEnabled
    )
    self.windowController = controller
    controller.showCanvas()
    configureStatusItem()
  }

  func applicationWillTerminate(_ notification: Notification) {
    let manager = serverManager
    Task { @MainActor in
      await manager?.stopAllServers()
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    openAppWindow(nil)
    return false
  }

  func applicationDidResignActive(_ notification: Notification) {
    guard appState.phase == .capsule else { return }
    windowController?.hideCapsule()
  }

  // MARK: - Status Item

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      let image = NSImage(named: "easelmenubar")
      image?.size = NSSize(width: 18, height: 18)
      image?.isTemplate = true
      image?.accessibilityDescription = "Easel"
      button.image = image
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    self.statusItem = item
  }

  @objc private func statusItemClicked(_ sender: Any?) {
    guard let button = statusItem?.button else { return }

    if let event = NSApp.currentEvent, event.type == .rightMouseUp {
      showContextMenu(from: button)
    } else if isFloatingChatBarEnabled {
      openChatBar(sender)
    } else {
      openAppWindow(sender)
    }
  }

  private func showContextMenu(from button: NSStatusBarButton) {
    let menu = buildStatusMenu()
    let location = NSPoint(x: 0, y: button.bounds.height + 4)
    menu.popUp(positioning: nil, at: location, in: button)
  }

  func buildStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let openWindowItem = NSMenuItem(
      title: "Open App Window",
      action: #selector(openAppWindow(_:)),
      keyEquivalent: ""
    )
    openWindowItem.target = self
    menu.addItem(openWindowItem)

    if isFloatingChatBarEnabled {
      let openChatBarItem = NSMenuItem(
        title: "Open Chat Bar",
        action: #selector(openChatBar(_:)),
        keyEquivalent: ""
      )
      openChatBarItem.target = self
      menu.addItem(openChatBarItem)
    }

    menu.addItem(NSMenuItem.separator())

    let checkForUpdatesItem = NSMenuItem(
      title: "Check for Updates...",
      action: #selector(checkForUpdatesFromMenu(_:)),
      keyEquivalent: ""
    )
    checkForUpdatesItem.target = self
    menu.addItem(checkForUpdatesItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "Quit Easel",
      action: #selector(quitApp(_:)),
      keyEquivalent: "q"
    )
    quitItem.keyEquivalentModifierMask = [.command]
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  // MARK: - Menu Actions

  @objc private func openAppWindow(_ sender: Any?) {
    guard let controller = windowController else { return }
    NSApp.activate(ignoringOtherApps: true)
    if appState.phase == .canvas {
      controller.canvasWindow.makeKeyAndOrderFront(nil)
    } else {
      appState.openCanvas()
    }
  }

  @objc private func openChatBar(_ sender: Any?) {
    guard isFloatingChatBarEnabled else {
      openAppWindow(sender)
      return
    }

    guard let controller = windowController else { return }
    NSApp.activate(ignoringOtherApps: true)
    if appState.phase == .canvas {
      appState.resetToCapsule()
    } else {
      controller.showCapsule()
    }
  }

  @objc func checkForUpdatesFromMenu(_ sender: Any?) {
    softwareUpdater.checkForUpdates()
  }

  @objc private func quitApp(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}
