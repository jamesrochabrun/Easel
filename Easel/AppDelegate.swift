//
//  AppDelegate.swift
//  Easel
//

import AppKit
import EaselKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowController: WindowController?
  let appState = AppState()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = WindowController(appState: appState)
    self.windowController = controller
    controller.showCapsule()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
