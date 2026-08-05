//
//  CodexCommandResolver.swift
//  ClaudeCodeUI
//

import CodexSDK
import Foundation

struct CodexCommandResolver {
  struct Resolution: Equatable {
    let path: String
    let source: Source
  }

  enum Source: Equatable {
    case override
    case localInstall
    case nvm
    case npmGlobal
    case toolShim
    case homebrew
    case path
    case sdkDetector
  }

  private let fileManager: FileManager
  private let homeDirectory: String
  private let pathEnvironment: String?
  private let homebrewDirectories: [String]
  private let sdkDetector: () -> String?

  init(
    fileManager: FileManager = .default,
    homeDirectory: String = NSHomeDirectory(),
    pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
    homebrewDirectories: [String] = ["/opt/homebrew/bin", "/usr/local/bin"],
    sdkDetector: @escaping () -> String? = {
      CodexBinaryDetector.detect()?.path
    }
  ) {
    self.fileManager = fileManager
    self.homeDirectory = homeDirectory
    self.pathEnvironment = pathEnvironment
    self.homebrewDirectories = homebrewDirectories
    self.sdkDetector = sdkDetector
  }

  func resolve(commandOverride: String? = nil) -> Resolution? {
    let trimmedOverride = commandOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedOverride.isEmpty {
      return Resolution(path: trimmedOverride, source: .override)
    }

    for candidate in executableCandidates() {
      if fileManager.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }

    if let detected = sdkDetector(), fileManager.isExecutableFile(atPath: detected) {
      return Resolution(path: detected, source: .sdkDetector)
    }

    for candidate in homebrewCandidates() {
      if fileManager.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }

    return nil
  }

  func searchPathDirectories() -> [String] {
    uniqueDirectories(
      candidateDirectories() + pathDirectories()
    )
  }

  private func executableCandidates() -> [Resolution] {
    let localCandidates: [Resolution] = [
      Resolution(path: "\(homeDirectory)/.codex/local/codex", source: .localInstall),
    ]

    let userManagedCandidates: [Resolution] = [
      Resolution(path: "\(homeDirectory)/.local/bin/codex", source: .localInstall),
      Resolution(path: "\(homeDirectory)/.npm-global/bin/codex", source: .npmGlobal),
      Resolution(path: "\(homeDirectory)/.nvm/current/bin/codex", source: .nvm),
      Resolution(path: "\(homeDirectory)/.volta/bin/codex", source: .toolShim),
      Resolution(path: "\(homeDirectory)/.local/share/mise/shims/codex", source: .toolShim),
      Resolution(path: "\(homeDirectory)/.asdf/shims/codex", source: .toolShim),
    ]

    let environmentCandidates = pathDirectories()
      .map { Resolution(path: "\($0)/codex", source: .path) }

    let scannedCandidates = nvmVersionCandidates()
      + fnmVersionCandidates()

    return localCandidates
      + environmentCandidates
      + userManagedCandidates
      + scannedCandidates
  }

  private func candidateDirectories() -> [String] {
    uniqueDirectories([
      "\(homeDirectory)/.codex/local",
    ] + pathDirectories() + [
      "\(homeDirectory)/.npm-global/bin",
      "\(homeDirectory)/.nvm/current/bin",
      "\(homeDirectory)/.volta/bin",
      "\(homeDirectory)/.local/share/mise/shims",
      "\(homeDirectory)/.asdf/shims",
      "/usr/bin",
      "\(homeDirectory)/.bun/bin",
      "\(homeDirectory)/.deno/bin",
      "\(homeDirectory)/.cargo/bin",
      "\(homeDirectory)/.local/bin",
    ] + nvmVersionDirectories() + fnmVersionDirectories() + homebrewDirectories)
  }

  private func homebrewCandidates() -> [Resolution] {
    homebrewDirectories.map { Resolution(path: "\($0)/codex", source: .homebrew) }
  }

  private func nvmVersionCandidates() -> [Resolution] {
    nvmVersionDirectories().map { Resolution(path: "\($0)/codex", source: .nvm) }
  }

  private func nvmVersionDirectories() -> [String] {
    childDirectories(at: "\(homeDirectory)/.nvm/versions/node")
      .map { "\($0)/bin" }
  }

  private func fnmVersionCandidates() -> [Resolution] {
    fnmVersionDirectories().map { Resolution(path: "\($0)/codex", source: .toolShim) }
  }

  private func fnmVersionDirectories() -> [String] {
    let roots = [
      "\(homeDirectory)/Library/Application Support/fnm/node-versions",
      "\(homeDirectory)/.local/share/fnm/node-versions",
      "\(homeDirectory)/.fnm/node-versions",
    ]

    return roots.flatMap { root in
      childDirectories(at: root).flatMap { versionDirectory in
        [
          "\(versionDirectory)/installation/bin",
          "\(versionDirectory)/bin",
        ]
      }
    }
  }

  private func childDirectories(at path: String) -> [String] {
    guard let children = try? fileManager.contentsOfDirectory(atPath: path) else {
      return []
    }

    return children
      .sorted(by: localizedVersionDescending)
      .map { "\(path)/\($0)" }
      .filter { isDirectory($0) }
  }

  private func pathDirectories() -> [String] {
    guard let pathEnvironment, !pathEnvironment.isEmpty else { return [] }

    return pathEnvironment
      .split(separator: ":", omittingEmptySubsequences: true)
      .map(String.init)
      .map(expandingTilde)
  }

  private func uniqueDirectories(_ directories: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for directory in directories where !directory.isEmpty {
      if seen.insert(directory).inserted {
        result.append(directory)
      }
    }

    return result
  }

  private func expandingTilde(_ path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else { return path }
    return homeDirectory + path.dropFirst()
  }

  private func isDirectory(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  private func localizedVersionDescending(_ lhs: String, _ rhs: String) -> Bool {
    lhs.compare(rhs, options: .numeric) == .orderedDescending
  }
}
