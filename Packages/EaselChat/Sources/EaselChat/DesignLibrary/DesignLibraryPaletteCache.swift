//
//  DesignLibraryPaletteCache.swift
//  EaselChat
//

import EaselDesignSystems
import Foundation

/// Lazily loads and caches the color palette for design-system cards so the
/// library grid can render swatches instead of a rendered "site" preview.
///
/// Catalogs live on disk (`<workingDirectory>/.easel/catalog.json`) and aren't
/// part of the lightweight `DesignLibraryItem`, so each design system's colors
/// are fetched on demand the first time its card appears and then reused.
@Observable @MainActor
final class DesignLibraryPaletteCache {
  private let designSystemManager: any EaselDesignSystemManaging
  private var palettesByDirectory: [String: [EaselDesignSystemColorToken]] = [:]
  private var inFlightDirectories: Set<String> = []
  private var emptyDirectories: Set<String> = []

  init(designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()) {
    self.designSystemManager = designSystemManager
  }

  /// The loaded colors for a design system, or `nil` if not loaded yet. An empty
  /// array means the catalog was loaded but had no usable colors (caller should
  /// fall back to the placeholder).
  func palette(for workingDirectory: String) -> [EaselDesignSystemColorToken]? {
    palettesByDirectory[workingDirectory]
  }

  /// Kicks off a one-time load of the palette for `workingDirectory` if it isn't
  /// already loaded, loading, or known to be empty. Safe to call on every render.
  func ensureLoaded(for workingDirectory: String) {
    guard palettesByDirectory[workingDirectory] == nil,
          !inFlightDirectories.contains(workingDirectory),
          !emptyDirectories.contains(workingDirectory)
    else { return }

    inFlightDirectories.insert(workingDirectory)
    Task {
      let colors = (try? await designSystemManager.loadCatalog(forDesignSystemAt: workingDirectory))?
        .tokens?.colors ?? []
      inFlightDirectories.remove(workingDirectory)
      if colors.isEmpty {
        emptyDirectories.insert(workingDirectory)
      } else {
        palettesByDirectory[workingDirectory] = colors
      }
    }
  }
}
