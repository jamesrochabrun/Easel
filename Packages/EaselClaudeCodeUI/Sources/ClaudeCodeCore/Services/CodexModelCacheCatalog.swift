//
//  CodexModelCacheCatalog.swift
//  ClaudeCodeUI
//

import Foundation

public struct CodexModelCacheCatalog: CodexModelCatalogProviding {
  private static let fallbackModelIdentifier = "gpt-5.5"
  private let debugModelsCommandRunner: any CodexDebugModelsCommandRunning

  public init() {
    self.debugModelsCommandRunner = CodexDebugModelsCommandRunner()
  }

  init(debugModelsCommandRunner: any CodexDebugModelsCommandRunning) {
    self.debugModelsCommandRunner = debugModelsCommandRunner
  }

  public func availableModels(homeDirectory: String = NSHomeDirectory()) async -> [CodexModelDescriptor] {
    if let refreshedData = try? await debugModelsCommandRunner.debugModelsJSON(homeDirectory: homeDirectory),
       let refreshedModels = try? Self.visibleModels(from: refreshedData),
       !refreshedModels.isEmpty {
      return refreshedModels
    }

    return cachedModels(homeDirectory: homeDirectory)
  }

  func cachedModels(homeDirectory: String = NSHomeDirectory()) -> [CodexModelDescriptor] {
    let cacheURL = URL(fileURLWithPath: homeDirectory)
      .appendingPathComponent(".codex/models_cache.json")

    guard let data = try? Data(contentsOf: cacheURL) else {
      return []
    }

    return (try? Self.visibleModels(from: data)) ?? []
  }

  public func configuredModelIdentifier(homeDirectory: String = NSHomeDirectory()) -> String? {
    let configURL = URL(fileURLWithPath: homeDirectory)
      .appendingPathComponent(".codex/config.toml")

    guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
      return nil
    }

    return Self.configuredModelIdentifier(in: contents)
  }

  public func defaultModelIdentifier(homeDirectory: String = NSHomeDirectory()) -> String {
    if let configured = configuredModelIdentifier(homeDirectory: homeDirectory) {
      return configured
    }

    if let cached = cachedModels(homeDirectory: homeDirectory).first?.slug {
      return cached
    }

    return Self.fallbackModelIdentifier
  }

  static func visibleModels(from data: Data) throws -> [CodexModelDescriptor] {
    let payload = try JSONDecoder().decode(ModelCachePayload.self, from: data)
    return payload.models
      .filter { ($0.visibility ?? "list") == "list" }
      .map {
        let displayName = $0.displayName?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = if let displayName, !displayName.isEmpty {
          displayName
        } else {
          $0.slug
        }
        return CodexModelDescriptor(
          slug: $0.slug,
          displayName: resolvedDisplayName,
          description: $0.description,
          visibility: $0.visibility,
          priority: $0.priority
        )
      }
      .sorted { lhs, rhs in
        let lhsPriority = lhs.priority ?? Int.max
        let rhsPriority = rhs.priority ?? Int.max
        if lhsPriority != rhsPriority {
          return lhsPriority < rhsPriority
        }
        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
      }
  }

  static func configuredModelIdentifier(in contents: String) -> String? {
    for rawLine in contents.split(whereSeparator: \.isNewline) {
      let line = lineWithoutComment(String(rawLine))
        .trimmingCharacters(in: .whitespacesAndNewlines)

      if line.hasPrefix("[") {
        return nil
      }

      guard let (key, value) = keyValuePair(from: line), key == "model" else {
        continue
      }

      return value.isEmpty ? nil : value
    }

    return nil
  }

  private static func keyValuePair(from line: String) -> (key: String, value: String)? {
    let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }

    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let value = parts[1]
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

    return (key, value)
  }

  private static func lineWithoutComment(_ line: String) -> String {
    guard let commentStart = line.firstIndex(of: "#") else { return line }
    return String(line[..<commentStart])
  }

  private struct ModelCachePayload: Decodable {
    let models: [CachedModel]
  }

  private struct CachedModel: Decodable {
    let slug: String
    let displayName: String?
    let description: String?
    let visibility: String?
    let priority: Int?

    private enum CodingKeys: String, CodingKey {
      case slug
      case displayName = "display_name"
      case description
      case visibility
      case priority
    }
  }
}
