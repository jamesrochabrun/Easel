//
//  DesignLibraryPaletteCache.swift
//  EaselChat
//

import EaselDesignSystems
import Foundation

/// The token snapshot a design-system card needs to render: the color palette
/// (swatch band + badge gradient) and a representative type token for the "Aa Bb"
/// specimen.
struct DesignSystemCardTokens: Equatable, Sendable {
  let colors: [EaselDesignSystemColorToken]
  let primaryType: EaselDesignSystemTypographyToken?

  var isEmpty: Bool { colors.isEmpty }
}

/// Lazily loads and caches the token snapshot for design-system cards so the
/// library grid can render the palette + type specimen instead of a rendered
/// "site" preview.
///
/// Catalogs live on disk (`<workingDirectory>/.easel/catalog.json`) and aren't
/// part of the lightweight `DesignLibraryItem`, so each design system's tokens
/// are fetched on demand the first time its card appears and then reused.
@Observable @MainActor
final class DesignLibraryPaletteCache {
  private let designSystemManager: any EaselDesignSystemManaging
  private var tokensByDirectory: [String: DesignSystemCardTokens] = [:]
  private var inFlightDirectories: Set<String> = []
  private var emptyDirectories: Set<String> = []

  init(designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()) {
    self.designSystemManager = designSystemManager
  }

  /// The loaded tokens for a design system, or `nil` if not loaded yet or the
  /// catalog had no usable colors (caller falls back to the placeholder).
  func tokens(for workingDirectory: String) -> DesignSystemCardTokens? {
    tokensByDirectory[workingDirectory]
  }

  /// Kicks off a one-time load for `workingDirectory` if it isn't already
  /// loaded, loading, or known to be empty. Safe to call on every render.
  func ensureLoaded(for workingDirectory: String) {
    guard tokensByDirectory[workingDirectory] == nil,
          !inFlightDirectories.contains(workingDirectory),
          !emptyDirectories.contains(workingDirectory)
    else { return }

    inFlightDirectories.insert(workingDirectory)
    Task {
      let tokenSet = (try? await designSystemManager.loadCatalog(forDesignSystemAt: workingDirectory))?.tokens
      let colors = tokenSet?.colors ?? []
      inFlightDirectories.remove(workingDirectory)
      if colors.isEmpty {
        emptyDirectories.insert(workingDirectory)
      } else {
        tokensByDirectory[workingDirectory] = DesignSystemCardTokens(
          colors: colors,
          primaryType: tokenSet?.typography.first
        )
      }
    }
  }
}
