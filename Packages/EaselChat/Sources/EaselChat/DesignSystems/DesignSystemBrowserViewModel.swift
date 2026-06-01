//
//  DesignSystemBrowserViewModel.swift
//  EaselChat
//

import Foundation

@Observable @MainActor
public final class DesignSystemBrowserViewModel {
  public private(set) var selectedChoice: EaselDesignSystemChoice?
  public private(set) var selectedCatalog: EaselDesignSystemCatalog?
  public private(set) var isLoadingCatalog = false
  public private(set) var errorMessage: String?

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
}
