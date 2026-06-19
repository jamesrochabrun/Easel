//
//  ClaudeModelCatalogProviding.swift
//  ClaudeCodeUI
//

import Foundation

public protocol ClaudeModelCatalogProviding: Sendable {
  func availableModels() async -> [ClaudeModelDescriptor]
}
