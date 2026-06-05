//
//  CodexModelCatalogProviding.swift
//  ClaudeCodeUI
//

import Foundation

public protocol CodexModelCatalogProviding {
  func availableModels(homeDirectory: String) async -> [CodexModelDescriptor]
  func configuredModelIdentifier(homeDirectory: String) -> String?
  func defaultModelIdentifier(homeDirectory: String) -> String
}
