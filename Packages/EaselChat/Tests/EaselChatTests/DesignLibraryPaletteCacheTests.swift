//
//  DesignLibraryPaletteCacheTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

@MainActor
struct DesignLibraryPaletteCacheTests {

  @Test
  func loadsColorsFromCatalog() async throws {
    let manager = PaletteCacheManagerStub(
      catalogsByPath: [
        "/ds/Sentry": makeCatalog(colors: [
          color("Primary", "#362D59"),
          color("Accent", "#FF45A8"),
        ])
      ]
    )
    let cache = DesignLibraryPaletteCache(designSystemManager: manager)

    // Not loaded yet.
    #expect(cache.palette(for: "/ds/Sentry") == nil)

    cache.ensureLoaded(for: "/ds/Sentry")
    let colors = try await waitForPalette(cache, path: "/ds/Sentry")

    #expect(colors.map(\.hex) == ["#362D59", "#FF45A8"])
  }

  @Test
  func catalogWithoutColorsStaysNil() async throws {
    let manager = PaletteCacheManagerStub(
      catalogsByPath: ["/ds/Empty": makeCatalog(colors: [])]
    )
    let cache = DesignLibraryPaletteCache(designSystemManager: manager)

    cache.ensureLoaded(for: "/ds/Empty")
    // Give the load a chance to complete.
    for _ in 0..<20 where manager.loadCount == 0 { await Task.yield() }
    try await Task.sleep(for: .milliseconds(50))

    // No usable colors -> palette stays nil so the card falls back to placeholder.
    #expect(cache.palette(for: "/ds/Empty") == nil)
  }

  @Test
  func loadsCatalogOnlyOnce() async throws {
    let manager = PaletteCacheManagerStub(
      catalogsByPath: ["/ds/Sentry": makeCatalog(colors: [color("Primary", "#362D59")])]
    )
    let cache = DesignLibraryPaletteCache(designSystemManager: manager)

    cache.ensureLoaded(for: "/ds/Sentry")
    _ = try await waitForPalette(cache, path: "/ds/Sentry")

    // Repeated calls after a successful load must not hit the manager again.
    cache.ensureLoaded(for: "/ds/Sentry")
    cache.ensureLoaded(for: "/ds/Sentry")
    await Task.yield()

    #expect(manager.loadCount == 1)
  }

  // MARK: - Helpers

  private func waitForPalette(
    _ cache: DesignLibraryPaletteCache,
    path: String
  ) async throws -> [EaselDesignSystemColorToken] {
    for _ in 0..<50 {
      if let colors = cache.palette(for: path), !colors.isEmpty {
        return colors
      }
      await Task.yield()
      try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Palette never loaded for \(path)")
    return []
  }

  private func color(_ name: String, _ hex: String) -> EaselDesignSystemColorToken {
    EaselDesignSystemColorToken(id: name, name: name, hex: hex, sourceNodeID: nil, sourceNodeName: nil, confidence: 1)
  }

  private func makeCatalog(colors: [EaselDesignSystemColorToken]) -> EaselDesignSystemCatalog {
    EaselDesignSystemCatalog(
      name: "Stub",
      summary: "",
      generatedAt: nil,
      componentGroups: [],
      tokens: EaselDesignSystemTokenSet(
        colors: colors,
        typography: [],
        spacing: [],
        radii: [],
        effects: []
      )
    )
  }
}

private final class PaletteCacheManagerStub: EaselDesignSystemManaging, @unchecked Sendable {
  private let catalogsByPath: [String: EaselDesignSystemCatalog]
  private(set) var loadCount = 0

  init(catalogsByPath: [String: EaselDesignSystemCatalog]) {
    self.catalogsByPath = catalogsByPath
  }

  func loadDesignSystems() async throws -> [EaselDesignSystemProfile] { [] }

  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    throw CancellationError()
  }

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {}

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    loadCount += 1
    return catalogsByPath[path]
  }
}
