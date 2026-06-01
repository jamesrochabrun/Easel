//
//  EaselDesignSystemLaunch.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemLaunch: Equatable, Sendable {
  public let profile: EaselDesignSystemProfile
  public let prompt: String

  public init(profile: EaselDesignSystemProfile, prompt: String) {
    self.profile = profile
    self.prompt = prompt
  }
}
