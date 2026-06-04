//
//  SlideDeckPresentationHandler.swift
//  EaselSlides
//

import AppKit
import SwiftUI

@MainActor
protocol SlideDeckPresentationHandling: AnyObject {
  func presentFullscreen(
    url: URL,
    selectedIndex: Int,
    reloadToken: UUID
  )

  func presentInNewTab(
    url: URL,
    selectedIndex: Int
  )
}

@MainActor
final class DefaultSlideDeckPresentationHandler: NSObject, SlideDeckPresentationHandling, NSWindowDelegate {
  private var fullscreenWindows: [NSWindow] = []

  func presentFullscreen(
    url: URL,
    selectedIndex: Int,
    reloadToken: UUID
  ) {
    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: selectedIndex
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    let rootView = SlideDeckPresentationView(
      url: presentationURL,
      initialSelectedIndex: selectedIndex,
      reloadToken: reloadToken
    ) { [weak window] in
      window?.close()
    }

    window.title = "Slides"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.collectionBehavior = [.fullScreenPrimary]
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = NSHostingView(rootView: rootView)
    fullscreenWindows.append(window)

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    window.toggleFullScreen(nil)
  }

  func presentInNewTab(
    url: URL,
    selectedIndex: Int
  ) {
    let presentationURL = SlideDeckPresentationURLFactory.presentationURL(
      for: url,
      selectedIndex: selectedIndex
    )
    NSWorkspace.shared.open(presentationURL)
  }

  func windowWillClose(_ notification: Notification) {
    guard let closingWindow = notification.object as? NSWindow else { return }
    fullscreenWindows.removeAll { $0 === closingWindow }
  }
}
