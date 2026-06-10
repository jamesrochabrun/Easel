//
//  DesignSystemSetupViewModel.swift
//  EaselChat
//

import Foundation
import EaselDesignSystems

@Observable @MainActor
public final class DesignSystemSetupViewModel {
  /// How the canonical `DESIGN.md` is sourced. Every mode produces a
  /// spec-compliant `DESIGN.md` plus the derived `catalog.json`.
  public enum CreationMode: String, CaseIterable, Identifiable, Sendable {
    /// Describe + attach resources (code/.fig/assets). `.fig` extract upgrades
    /// the DESIGN.md during import.
    case describe
    /// Import and normalize an existing `DESIGN.md`.
    case importMarkdown
    /// Generate a DESIGN.md from the description via an LLM.
    case generate

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .describe: return "Describe & attach"
      case .importMarkdown: return "Import DESIGN.md"
      case .generate: return "Generate with AI"
      }
    }
  }

  public var creationMode: CreationMode = .describe
  /// Optional explicit name for the Import / Generate modes.
  public var nameDraft = ""
  public var blurb = ""
  public var sourceLinkDraft = ""
  public private(set) var sourceLinks: [String] = []
  public private(set) var codeSourceURLs: [URL] = []
  public private(set) var figFileURLs: [URL] = []
  public private(set) var assetURLs: [URL] = []
  public private(set) var designMarkdownURL: URL?
  /// Raw DESIGN.md pasted directly into the form (takes priority over a file).
  public var designMarkdownText = ""
  public var notes = ""
  public private(set) var isCreating = false
  public private(set) var errorMessage: String?

  private let designSystemManager: any EaselDesignSystemManaging

  public init(
    designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager(
      designMarkdownGenerator: ClaudeDesignMarkdownGenerator()
    )
  ) {
    self.designSystemManager = designSystemManager
  }

  public var canCreate: Bool {
    guard !isCreating else { return false }
    switch creationMode {
    case .describe, .generate:
      return !blurb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .importMarkdown:
      return designMarkdownURL != nil || !designMarkdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  public func addSourceLink() {
    let trimmed = sourceLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !sourceLinks.contains(trimmed) else { return }
    sourceLinks.append(trimmed)
    sourceLinkDraft = ""
  }

  public func removeSourceLink(_ link: String) {
    sourceLinks.removeAll { $0 == link }
  }

  public func addCodeSources(_ urls: [URL]) {
    codeSourceURLs = Self.appendingUnique(urls, to: codeSourceURLs)
  }

  public func addFigFiles(_ urls: [URL]) {
    // Only accept .fig files so non-Figma files can't be added by accident.
    let figURLs = urls.filter { $0.pathExtension.lowercased() == "fig" }
    figFileURLs = Self.appendingUnique(figURLs, to: figFileURLs)
  }

  public func addAssets(_ urls: [URL]) {
    assetURLs = Self.appendingUnique(urls, to: assetURLs)
  }

  public func addDesignMarkdown(_ urls: [URL]) {
    // Accept only Markdown so other files can't be selected by accident.
    designMarkdownURL = urls.first { $0.pathExtension.lowercased() == "md" } ?? designMarkdownURL
  }

  public func removeDesignMarkdown() {
    designMarkdownURL = nil
  }

  public func removeCodeSource(_ url: URL) {
    codeSourceURLs.removeAll { $0 == url }
  }

  public func removeFigFile(_ url: URL) {
    figFileURLs.removeAll { $0 == url }
  }

  public func removeAsset(_ url: URL) {
    assetURLs.removeAll { $0 == url }
  }

  public func createDesignSystem() async -> EaselDesignSystemLaunch? {
    guard canCreate else { return nil }

    isCreating = true
    defer { isCreating = false }

    do {
      addSourceLink()
      let request = EaselDesignSystemCreateRequest(
        blurb: blurb,
        sourceLinks: sourceLinks,
        codeSourceURLs: codeSourceURLs,
        figFileURLs: figFileURLs,
        figImportMode: .extractCatalog,
        assetURLs: assetURLs,
        notes: notes,
        source: makeSource(),
        nameHint: nameDraft
      )
      let profile = try await designSystemManager.createDesignSystem(from: request)
      errorMessage = nil
      reset()
      return EaselDesignSystemLaunch(profile: profile)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  private func makeSource() -> EaselDesignSystemCreateRequest.Source {
    switch creationMode {
    case .describe:
      return .resources
    case .generate:
      return .prompt(blurb)
    case .importMarkdown:
      let pasted = designMarkdownText.trimmingCharacters(in: .whitespacesAndNewlines)
      if !pasted.isEmpty {
        return .designMarkdownText(pasted)
      }
      return designMarkdownURL.map { .designMarkdown($0) } ?? .resources
    }
  }

  public func reportImportFailure(_ error: Error) {
    errorMessage = error.localizedDescription
  }

  private func reset() {
    creationMode = .describe
    nameDraft = ""
    blurb = ""
    sourceLinkDraft = ""
    sourceLinks = []
    codeSourceURLs = []
    figFileURLs = []
    assetURLs = []
    designMarkdownURL = nil
    designMarkdownText = ""
    notes = ""
  }

  private static func appendingUnique(_ urls: [URL], to existingURLs: [URL]) -> [URL] {
    var result = existingURLs
    for url in urls where !result.contains(url) {
      result.append(url)
    }
    return result
  }
}
