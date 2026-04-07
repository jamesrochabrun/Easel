//
//  KeyablePanel.swift
//  Easel
//

import AppKit

final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
