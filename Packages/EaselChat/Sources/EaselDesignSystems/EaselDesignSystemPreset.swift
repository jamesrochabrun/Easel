//
//  EaselDesignSystemPreset.swift
//  EaselDesignSystems
//

import Foundation

/// The built-in (non-custom) design system option. Only "no design system"
/// remains — custom, locally-parsed design systems are the way to bring real
/// tokens/components into a project.
public enum EaselDesignSystemPreset: String, CaseIterable, Codable, Identifiable, Sendable {
  case none

  public var id: String { rawValue }

  public var displayName: String {
    "No design system"
  }

  public var detail: String {
    "Start without a design system"
  }
}
