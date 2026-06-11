//
//  SoftwareUpdating.swift
//  Easel
//

@MainActor
protocol SoftwareUpdating: AnyObject {
  func checkForUpdates()
}
