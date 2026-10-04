//
//  ArnesModelCatalog.swift
//  ClaudeCodeUI
//

import Foundation

/// Runs `arnes models --json` and returns its stdout. Injected so tests can
/// feed fixture JSON without spawning a process.
public protocol ArnesModelsCommandRunning: Sendable {
  func modelsJSON() async throws -> Data
}

/// Model catalog for the Arnes (OpenRouter) provider, backed by the CLI's
/// manifest cache (`arnes models --json` is served from `~/.arnes/models`
/// for 24h, so this is fast and works offline once fetched).
public struct ArnesModelCatalog: ArnesModelCatalogProviding {
  private let commandRunner: any ArnesModelsCommandRunning

  public init(commandRunner: any ArnesModelsCommandRunning = ArnesModelsCommandRunner()) {
    self.commandRunner = commandRunner
  }

  public func availableModels() async -> [ArnesModelDescriptor] {
    guard let data = try? await commandRunner.modelsJSON() else {
      return [.auto]
    }

    return Self.descriptors(fromModelsJSON: data)
  }

  public func defaultModelIdentifier() -> String {
    ArnesModelDescriptor.autoIdentifier
  }

  /// Parses the `arnes models --json` document into picker descriptors:
  /// `Auto` first, then every tool-capable model (the agent loop needs tool
  /// calling) sorted by identifier.
  static func descriptors(fromModelsJSON data: Data) -> [ArnesModelDescriptor] {
    guard let rows = try? JSONDecoder().decode([ManifestRow].self, from: data) else {
      return [.auto]
    }

    let models = rows
      .filter {
        $0.supportsTools == true
          && $0.id != ArnesModelDescriptor.autoIdentifier
          // Batch endpoints trade latency for price — not for interactive chat.
          && !$0.id.hasSuffix(":batch")
      }
      .map { row in
        ArnesModelDescriptor(
          identifier: row.id,
          displayName: row.id,
          detail: Self.detail(for: row),
          contextLength: row.contextLength,
          supportsTools: row.supportsTools ?? false,
          supportsReasoning: row.supportsReasoning ?? false,
          supportsVision: row.supportsVision ?? false,
          promptPricePerToken: row.promptPricePerToken,
          completionPricePerToken: row.completionPricePerToken
        )
      }
      .sorted { $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == .orderedAscending }

    return [.auto] + models
  }

  static func detail(for row: ManifestRow) -> String? {
    var parts: [String] = []

    if let context = row.contextLength, context > 0 {
      parts.append(Self.formattedContext(context))
    }
    if let input = row.promptPricePerToken, let output = row.completionPricePerToken {
      if input == 0, output == 0 {
        parts.append("free")
      } else {
        parts.append("$\(Self.perMillion(input))/\(Self.perMillion(output)) per M tokens")
      }
    }
    if row.supportsReasoning == true {
      parts.append("reasoning")
    }
    if row.supportsVision == true {
      parts.append("vision")
    }

    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private static func formattedContext(_ tokens: Int) -> String {
    if tokens >= 1_000_000 {
      let millions = Double(tokens) / 1_000_000
      let value = millions == millions.rounded() ? String(Int(millions)) : String(format: "%.1f", millions)
      return "\(value)M ctx"
    }
    return "\(tokens / 1_000)K ctx"
  }

  private static func perMillion(_ perToken: Double) -> String {
    let value = perToken * 1_000_000
    if value == value.rounded() {
      return String(Int(value))
    }
    return String(format: "%.2f", value)
  }

  struct ManifestRow: Decodable {
    let id: String
    let contextLength: Int?
    let supportsTools: Bool?
    let supportsReasoning: Bool?
    let supportsVision: Bool?
    let promptPricePerToken: Double?
    let completionPricePerToken: Double?

    enum CodingKeys: String, CodingKey {
      case id
      case contextLength = "context_length"
      case supportsTools = "supports_tools"
      case supportsReasoning = "supports_reasoning"
      case supportsVision = "supports_vision"
      case promptPricePerToken = "prompt_price_per_token"
      case completionPricePerToken = "completion_price_per_token"
    }
  }
}

public struct ArnesModelsCommandRunner: ArnesModelsCommandRunning {
  private let commandOverride: String?
  private let environmentOverrides: [String: String]

  public init(commandOverride: String? = nil, environmentOverrides: [String: String] = [:]) {
    self.commandOverride = commandOverride
    self.environmentOverrides = environmentOverrides
  }

  public func modelsJSON() async throws -> Data {
    let executable = ArnesExecutableResolver.resolve(commandOverride: commandOverride)
    let environmentOverrides = environmentOverrides
    return try await Task.detached(priority: .utility) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      // `arnes models` defaults to 20 results; 1000 is the API maximum and
      // covers the whole manifest.
      process.arguments = ArnesExecutableResolver.argumentsPrefix(forExecutable: executable)
        + ["models", "--json", "--limit", "1000"]
      process.environment = ArnesExecutableResolver.environment(overrides: environmentOverrides)

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      try process.run()
      let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let message = String(data: errorData, encoding: .utf8) ?? "arnes models failed"
        throw ArnesCommandError.nonZeroExit(message)
      }

      return output
    }.value
  }
}

enum ArnesCommandError: LocalizedError {
  case nonZeroExit(String)
  case executableNotFound

  var errorDescription: String? {
    switch self {
    case .nonZeroExit(let message):
      return message
    case .executableNotFound:
      return "Could not find the 'arnes' command. Install it or set its path in Settings."
    }
  }
}

/// Resolves the arnes executable and the environment its processes launch
/// with (GUI apps inherit a minimal PATH, so common install locations are
/// appended explicitly).
enum ArnesExecutableResolver {
  static func resolve(commandOverride: String?) -> String {
    let trimmed = commandOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmed.isEmpty {
      if trimmed.contains("/") {
        return (trimmed as NSString).expandingTildeInPath
      }
      if let found = TerminalLauncher.findExecutable(command: trimmed, additionalPaths: searchPaths()) {
        return found
      }
      return trimmed
    }

    if let found = TerminalLauncher.findExecutable(command: "arnes", additionalPaths: searchPaths()) {
      return found
    }
    return "/usr/bin/env"
  }

  /// Arguments prefix needed when `resolve` fell back to `/usr/bin/env`.
  static func argumentsPrefix(forExecutable executable: String) -> [String] {
    executable == "/usr/bin/env" ? ["arnes"] : []
  }

  static func environment(overrides: [String: String] = [:]) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let paths = searchPaths()
    if let currentPath = environment["PATH"], !currentPath.isEmpty {
      environment["PATH"] = (paths + [currentPath]).joined(separator: ":")
    } else {
      environment["PATH"] = paths.joined(separator: ":")
    }

    for (key, value) in overrides {
      let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedKey.isEmpty else { continue }
      environment[trimmedKey] = value
    }
    return environment
  }

  private static func searchPaths() -> [String] {
    let homeDirectory = NSHomeDirectory()
    return [
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "\(homeDirectory)/.local/bin",
      "\(homeDirectory)/bin",
    ]
  }
}
