//
//  APIModelCatalogProviding.swift
//  ClaudeCodeUI
//

import AgentHarness
import Foundation

/// Lists the models an endpoint profile can serve (for the settings model
/// picker and connection testing). Mirrors `CodexModelCatalogProviding` for
/// the Local / API provider.
public protocol APIModelCatalogProviding: Sendable {
  func availableModels(profile: EndpointProfile, apiKey: String?) async throws -> [AgentModelInfo]
}
