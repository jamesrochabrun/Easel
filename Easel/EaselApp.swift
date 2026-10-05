//
//  EaselApp.swift
//  Easel
//
//  Created by James Rochabrun on 3/22/26.
//

import EaselKit
import EaselChat
import EaselStudio
import SwiftUI

@main
struct EaselApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      TabView {
        EaselChatSettingsView(chatService: appDelegate.chatService)
          .tabItem { Label("Assistant", systemImage: "bubble.left.and.bubble.right") }

        StudioSettingsView(library: appDelegate.studioCoordinator.library)
          .tabItem { Label("Studio", systemImage: "paintpalette") }
      }
      .tint(EaselDesignSystem.Palette.accent)
    }
    .commands {
      CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
          appDelegate.checkForUpdatesFromMenu(nil)
        }
      }
    }
  }
}
