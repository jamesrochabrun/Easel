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
  public private(set) var errorMessage: String?
  private var selectedWorkingDirectory: String?

  private let designSystemManager: any EaselDesignSystemManaging

  public init(designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()) {
    self.designSystemManager = designSystemManager
  }

  public func select(_ choice: EaselDesignSystemChoice) async {
    selectedChoice = choice
    selectedWorkingDirectory = choice.workingDirectory
    errorMessage = nil
    let selectedChoiceID = choice.id

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
      let catalog = try await designSystemManager.loadCatalog(forDesignSystemAt: workingDirectory)
        ?? EaselDesignSystemCatalog(
          name: choice.displayName,
          summary: "The generated catalog will appear after Codex writes `.easel/catalog.json`.",
          generatedAt: nil,
          componentGroups: []
        )
      guard selectedChoice?.id == selectedChoiceID else { return }
      selectedCatalog = catalog
    } catch {
      guard selectedChoice?.id == selectedChoiceID else { return }
      selectedCatalog = nil
      errorMessage = error.localizedDescription
    }
  }

  public func previewURL(for previewPath: String?) -> URL? {
    guard let previewPath,
          !previewPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }

    if let url = URL(string: previewPath), url.scheme != nil {
      return url
    }

    guard let selectedWorkingDirectory else {
      return nil
    }

    return URL(fileURLWithPath: selectedWorkingDirectory)
      .appendingPathComponent(previewPath)
  }
}
