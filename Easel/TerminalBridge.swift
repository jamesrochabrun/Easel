//
//  TerminalBridge.swift
//  Easel
//
//  Observable bridge for webview inspector → terminal communication.
//

import Foundation

@Observable @MainActor
final class TerminalBridge {
  private weak var container: EaselTerminalContainerView?
  let localhostDetector: TerminalOutputLocalhostDetector

  init(localhostDetector: TerminalOutputLocalhostDetector = .init()) {
    self.localhostDetector = localhostDetector
  }

  func register(_ container: EaselTerminalContainerView) {
    self.container = container
  }

  func sendPrompt(_ prompt: String) {
    container?.resetPromptDeliveryFlag()
    container?.sendPromptIfNeeded(prompt)
  }

  func typeText(_ text: String) {
    container?.typeText(text)
  }
}
