//
//  ArnesModelCatalogProviding.swift
//  ClaudeCodeUI
//

import Foundation

public protocol ArnesModelCatalogProviding: Sendable {
  /// Models available on the active Arnes provider (OpenRouter manifest),
  /// with `Auto` pinned first. Empty on failure — callers show the Auto
  /// option and free-text entry regardless.
  func availableModels() async -> [ArnesModelDescriptor]

  /// The identifier used when the user has not picked a model.
  func defaultModelIdentifier() -> String
}
