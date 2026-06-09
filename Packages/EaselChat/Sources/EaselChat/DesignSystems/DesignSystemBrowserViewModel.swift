//
//  DesignSystemBrowserViewModel.swift
//  EaselChat
//

import Foundation
import EaselDesignSystems

@Observable @MainActor
public final class DesignSystemBrowserViewModel {
  public private(set) var selectedChoice: EaselDesignSystemChoice?
  public private(set) var selectedCatalog: EaselDesignSystemCatalog?
  public private(set) var isLoadingCatalog = false
  public private(set) var isRegenerating = false
  public private(set) var errorMessage: String?

  /// Whether the selected design system has a local folder that can be re-imported.
  public var canRegenerate: Bool {
    selectedChoice?.kind == .custom && selectedChoice?.workingDirectory != nil
  }

  private let designSystemManager: any EaselDesignSystemManaging

  public init(designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()) {
    self.designSystemManager = designSystemManager
  }

  public func select(_ choice: EaselDesignSystemChoice) async {
    selectedChoice = choice
    errorMessage = nil

    if let preset = choice.preset {
      selectedCatalog = preset.catalog
      return
    }

    guard let workingDirectory = choice.workingDirectory else {
      selectedCatalog = EaselDesignSystemCatalog(
        name: choice.displayName,
        summary: "This design system does not have a local folder.",
        generatedAt: nil,
        componentGroups: []
      )
      return
    }

    isLoadingCatalog = true
    defer { isLoadingCatalog = false }

    do {
      selectedCatalog = try await designSystemManager.loadCatalog(forDesignSystemAt: workingDirectory)
        ?? EaselDesignSystemCatalog(
          name: choice.displayName,
          summary: "The generated catalog will appear after Codex writes `.easel/catalog.json`.",
          generatedAt: nil,
          componentGroups: []
        )
    } catch {
      selectedCatalog = nil
      errorMessage = error.localizedDescription
    }
  }

  /// Re-runs the import pipeline for the selected local design system and shows
  /// the freshly generated catalog. The parser's cached output is reused, so an
  /// unchanged source skips re-parsing.
  public func regenerate() async {
    guard let workingDirectory = selectedChoice?.workingDirectory else { return }

    isRegenerating = true
    defer { isRegenerating = false }
    errorMessage = nil

    do {
      let result = try await designSystemManager.regenerateDesignSystem(forDesignSystemAt: workingDirectory)
      if let catalog = result.catalog {
        selectedCatalog = catalog
      } else if let reloaded = try await designSystemManager.loadCatalog(forDesignSystemAt: workingDirectory) {
        selectedCatalog = reloaded
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
