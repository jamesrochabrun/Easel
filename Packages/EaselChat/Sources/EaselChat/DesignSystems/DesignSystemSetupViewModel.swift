//
//  DesignSystemSetupViewModel.swift
//  EaselChat
//

import Foundation
import EaselDesignSystems

@Observable @MainActor
public final class DesignSystemSetupViewModel {
  public var blurb = ""
  public var sourceLinkDraft = ""
  public private(set) var sourceLinks: [String] = []
  public private(set) var codeSourceURLs: [URL] = []
  public private(set) var figFileURLs: [URL] = []
  public private(set) var assetURLs: [URL] = []
  public var notes = ""
  public private(set) var isCreating = false
  public private(set) var errorMessage: String?

  private let designSystemManager: any EaselDesignSystemManaging

  public init(designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()) {
    self.designSystemManager = designSystemManager
  }

  public var canCreate: Bool {
    !blurb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
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
    figFileURLs = Self.appendingUnique(urls, to: figFileURLs)
  }

  public func addAssets(_ urls: [URL]) {
    assetURLs = Self.appendingUnique(urls, to: assetURLs)
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
        assetURLs: assetURLs,
        notes: notes
      )
      let profile = try await designSystemManager.createDesignSystem(from: request)
      errorMessage = nil
      reset()
      return EaselDesignSystemLaunch(profile: profile, prompt: profile.creationPrompt())
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  public func reportImportFailure(_ error: Error) {
    errorMessage = error.localizedDescription
  }

  private func reset() {
    blurb = ""
    sourceLinkDraft = ""
    sourceLinks = []
    codeSourceURLs = []
    figFileURLs = []
    assetURLs = []
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
