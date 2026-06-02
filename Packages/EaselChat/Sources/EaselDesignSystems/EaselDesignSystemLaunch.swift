//
//  EaselDesignSystemLaunch.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemLaunch: Equatable, Sendable {
  public let profile: EaselDesignSystemProfile

  public init(profile: EaselDesignSystemProfile) {
    self.profile = profile
  }
}
