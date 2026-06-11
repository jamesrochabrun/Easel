//
//  SparkleSoftwareUpdater.swift
//  Easel
//

import Sparkle

@MainActor
final class SparkleSoftwareUpdater: SoftwareUpdating {
  private let updaterController: SPUStandardUpdaterController

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }
}
