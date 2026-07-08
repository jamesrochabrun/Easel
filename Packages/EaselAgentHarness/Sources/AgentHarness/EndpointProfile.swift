import Foundation

/// A named, user-configurable endpoint (secrets-free — API keys live in the
/// host app's credential store, keyed by `id`).
public struct EndpointProfile: Sendable, Codable, Equatable, Identifiable {
  public enum Kind: String, Sendable, Codable, CaseIterable {
    /// Any OpenAI-compatible /v1 endpoint (LM Studio, llama.cpp, OpenRouter,
    /// Groq, DeepSeek, xAI, vLLM…).
    case openAICompatible
    /// Ollama's native /api/chat (preferred over its /v1 shim, which has
    /// known streaming+tools bugs).
    case ollamaNative
    /// In-process inference via MLX on Apple Silicon.
    case mlxLocal
  }

  /// Stable identifier; also the credential-store account key.
  public var id: String
  public var name: String
  public var kind: Kind
  /// Ignored for `.mlxLocal`.
  public var baseURL: String
  public var defaultModel: String
  public var requiresAPIKey: Bool
  /// Extra HTTP headers (e.g. OpenRouter's HTTP-Referer / X-Title).
  public var extraHeaders: [String: String]
  public var capabilities: ModelCapabilities

  /// How the endpoint is grouped and configured in the UI.
  public enum Category: Sendable {
    /// A server running on this machine (Ollama, LM Studio, llama.cpp) —
    /// configured with a base URL, no API key.
    case localServer
    /// In-process inference on this machine (MLX) — no URL or key.
    case onDevice
    /// A hosted provider (OpenRouter, Groq, …) — configured with an API key.
    case hosted
  }

  public var category: Category {
    switch kind {
    case .mlxLocal: return .onDevice
    case .ollamaNative: return .localServer
    case .openAICompatible: return requiresAPIKey ? .hosted : .localServer
    }
  }

  /// True for the built-in presets (fixed providers the user can't rename or
  /// delete); false for user-added custom endpoints.
  public var isPreset: Bool {
    id.hasPrefix("preset-")
  }

  public init(
    id: String,
    name: String,
    kind: Kind,
    baseURL: String,
    defaultModel: String = "",
    requiresAPIKey: Bool = false,
    extraHeaders: [String: String] = [:],
    capabilities: ModelCapabilities = ModelCapabilities()
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.baseURL = baseURL
    self.defaultModel = defaultModel
    self.requiresAPIKey = requiresAPIKey
    self.extraHeaders = extraHeaders
    self.capabilities = capabilities
  }
}

extension EndpointProfile {
  /// One-click presets seeded into settings on first launch. Ids are fixed
  /// strings (not random UUIDs) so credential-store accounts stay stable.
  public static func builtInPresets() -> [EndpointProfile] {
    [
      EndpointProfile(
        id: "preset-ollama",
        name: "Ollama",
        kind: .ollamaNative,
        baseURL: "http://localhost:11434",
        capabilities: ModelCapabilities(
          supportsParallelToolCalls: false,
          contextWindowTokens: 16_384
        )
      ),
      EndpointProfile(
        id: "preset-lmstudio",
        name: "LM Studio",
        kind: .openAICompatible,
        baseURL: "http://localhost:1234/v1",
        capabilities: ModelCapabilities(contextWindowTokens: 16_384)
      ),
      EndpointProfile(
        id: "preset-llamacpp",
        name: "llama.cpp",
        kind: .openAICompatible,
        baseURL: "http://localhost:8080/v1",
        capabilities: ModelCapabilities(contextWindowTokens: 16_384)
      ),
      EndpointProfile(
        id: "preset-mlx",
        name: "On-Device (MLX)",
        kind: .mlxLocal,
        baseURL: "",
        capabilities: ModelCapabilities(
          supportsParallelToolCalls: false,
          contextWindowTokens: 8_192
        )
      ),
      EndpointProfile(
        id: "preset-openrouter",
        name: "OpenRouter",
        kind: .openAICompatible,
        baseURL: "https://openrouter.ai/api/v1",
        requiresAPIKey: true,
        capabilities: ModelCapabilities(contextWindowTokens: 128_000)
      ),
      EndpointProfile(
        id: "preset-groq",
        name: "Groq",
        kind: .openAICompatible,
        baseURL: "https://api.groq.com/openai/v1",
        requiresAPIKey: true,
        capabilities: ModelCapabilities(contextWindowTokens: 128_000)
      ),
      EndpointProfile(
        id: "preset-deepseek",
        name: "DeepSeek",
        kind: .openAICompatible,
        baseURL: "https://api.deepseek.com/v1",
        requiresAPIKey: true,
        capabilities: ModelCapabilities(contextWindowTokens: 64_000)
      ),
      EndpointProfile(
        id: "preset-xai",
        name: "xAI",
        kind: .openAICompatible,
        baseURL: "https://api.x.ai/v1",
        requiresAPIKey: true,
        capabilities: ModelCapabilities(contextWindowTokens: 128_000)
      ),
    ]
  }
}
