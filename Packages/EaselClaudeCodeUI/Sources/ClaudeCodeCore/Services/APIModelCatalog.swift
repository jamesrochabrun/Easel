//
//  APIModelCatalog.swift
//  ClaudeCodeUI
//

import AgentHarness
import AgentProviderOllama
import AgentProviderOpenAI
import Foundation

/// Default `APIModelCatalogProviding`: dispatches on the profile kind to the
/// matching model client and keeps a short in-memory cache so repeated picker
/// refreshes don't hammer local servers.
public actor APIModelCatalog: APIModelCatalogProviding {
  /// Test seam: injects scripted clients instead of real network backends.
  public typealias ClientFactory = @Sendable (EndpointProfile, String?) -> any AgentModelClient

  private struct CacheEntry {
    let models: [AgentModelInfo]
    let fetchedAt: Date
  }

  private let clientFactory: ClientFactory
  private let cacheLifetime: TimeInterval
  private var cache: [String: CacheEntry] = [:]

  public init(
    cacheLifetime: TimeInterval = 60,
    clientFactory: @escaping ClientFactory = APIModelCatalog.defaultClientFactory
  ) {
    self.cacheLifetime = cacheLifetime
    self.clientFactory = clientFactory
  }

  public func availableModels(profile: EndpointProfile, apiKey: String?) async throws -> [AgentModelInfo] {
    // On-device models change whenever the user downloads or deletes one, and
    // querying the local manager is cheap — never serve MLX from the cache so
    // a freshly downloaded model appears immediately.
    if profile.kind == .mlxLocal {
      return try await clientFactory(profile, apiKey).listModels()
    }

    let key = Self.cacheKey(for: profile)
    if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < cacheLifetime {
      return entry.models
    }

    let client = clientFactory(profile, apiKey)
    let models = try await client.listModels()
    cache[key] = CacheEntry(models: models, fetchedAt: Date())
    return models
  }

  public static let defaultClientFactory: ClientFactory = { profile, apiKey in
    switch profile.kind {
    case .ollamaNative:
      return OllamaNativeModelClient(profile: profile)
    case .openAICompatible:
      return OpenAICompatibleModelClient(profile: profile, apiKey: apiKey)
    case .mlxLocal:
      // The MLX-aware factory is injected by the embedding app; without it,
      // there is nothing to list.
      return UnavailableModelClient(
        profile: profile,
        reason: "On-device MLX models are managed by the app."
      )
    }
  }

  private static func cacheKey(for profile: EndpointProfile) -> String {
    "\(profile.id)|\(profile.baseURL)"
  }
}
