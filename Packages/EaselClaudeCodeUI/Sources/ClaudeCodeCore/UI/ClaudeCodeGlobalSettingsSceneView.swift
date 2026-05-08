//
//  ClaudeCodeGlobalSettingsSceneView.swift
//  ClaudeCodeUI
//

import SwiftUI
import CCPermissionsServiceInterface

public struct ClaudeCodeGlobalSettingsSceneView: View {
  private let uiConfiguration: UIConfiguration
  private let xcodeObservationViewModel: XcodeObservationViewModel?
  private let permissionsService: PermissionsService?
  private let chatViewModel: ChatViewModel?
  private let providedGlobalPreferences: GlobalPreferencesStorage?

  @State private var ownedGlobalPreferences = GlobalPreferencesStorage()
  @State private var appearanceSettings = AppearanceSettings()

  public init(
    uiConfiguration: UIConfiguration = .default,
    xcodeObservationViewModel: XcodeObservationViewModel? = nil,
    permissionsService: PermissionsService? = nil,
    chatViewModel: ChatViewModel? = nil,
    globalPreferences: GlobalPreferencesStorage? = nil
  ) {
    self.uiConfiguration = uiConfiguration
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.chatViewModel = chatViewModel
    self.providedGlobalPreferences = globalPreferences
  }

  public var body: some View {
    GlobalSettingsView(
      uiConfiguration: uiConfiguration,
      xcodeObservationViewModel: xcodeObservationViewModel,
      permissionsService: permissionsService,
      chatViewModel: chatViewModel
    )
    .environment(activeGlobalPreferences)
    .environment(appearanceSettings)
  }

  private var activeGlobalPreferences: GlobalPreferencesStorage {
    providedGlobalPreferences ?? ownedGlobalPreferences
  }
}
