//
//  EaselApp.swift
//  Easel
//
//  Created by James Rochabrun on 3/22/26.
//

import EaselKit
import EaselChat
import SwiftUI

@main
struct EaselApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EaselChatSettingsView(chatService: appDelegate.chatService)
        .tint(EaselDesignSystem.Palette.accent)
    }
  }
}
