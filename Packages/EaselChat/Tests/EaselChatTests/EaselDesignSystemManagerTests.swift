//
//  EaselDesignSystemManagerTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselChat

struct EaselDesignSystemManagerTests {

  @Test
  func createDesignSystemWritesMetadataScaffoldAndResources() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemManagerTests")
    let sourceDirectory = temporaryRoot(named: "DesignSystemSourceTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: sourceDirectory)
    }

    let codeDirectory = sourceDirectory.appendingPathComponent("Frontend", isDirectory: true)
    let nodeModulesDirectory = codeDirectory.appendingPathComponent("node_modules", isDirectory: true)
    try FileManager.default.createDirectory(at: nodeModulesDirectory, withIntermediateDirectories: true)
    try Data("view".utf8).write(to: codeDirectory.appendingPathComponent("App.swift"))
    try Data("ignored".utf8).write(to: nodeModulesDirectory.appendingPathComponent("ignored.js"))

    let figURL = sourceDirectory.appendingPathComponent("Brand.fig")
    let logoURL = sourceDirectory.appendingPathComponent("logo.png")
    try Data([0, 1, 2]).write(to: figURL)
    try Data([3, 4, 5]).write(to: logoURL)

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Mission Impastabowl: fast-casual pasta restaurant",
      sourceLinks: ["https://github.com/example/brand"],
      codeSourceURLs: [codeDirectory],
      figFileURLs: [figURL],
      assetURLs: [logoURL],
      notes: "Warm palette"
    ))

    #expect(profile.name == "Mission Impastabowl")
    #expect(profile.sourceLinks == ["https://github.com/example/brand"])
    #expect(profile.notes == "Warm palette")

    let designSystemURL = URL(fileURLWithPath: profile.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("README.md").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("package.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent(".easel/design-system.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/App.swift").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/node_modules/ignored.js").path) == false)
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/figma/Brand.fig").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/assets/logo.png").path))

    let loadedSystems = try await manager.loadDesignSystems()
    #expect(loadedSystems.map(\.id) == [profile.id])
    #expect(profile.creationPrompt().contains(".easel/catalog.json"))
    #expect(profile.creationPrompt().contains("resources/"))
  }

  @Test
  func createDesignSystemUsesUniqueFoldersForDuplicateNames() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemDuplicateTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let request = EaselDesignSystemCreateRequest(
      blurb: "AgentHub Design System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    )

    let first = try await manager.createDesignSystem(from: request)
    let second = try await manager.createDesignSystem(from: request)

    #expect(first.workingDirectory.hasSuffix("/agenthub-design-system"))
    #expect(second.workingDirectory.hasSuffix("/agenthub-design-system-2"))
  }

  @Test
  func loadCatalogReadsGeneratedCatalogMetadata() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemCatalogTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Catalog System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))
    let designSystemURL = URL(fileURLWithPath: profile.workingDirectory)
    let catalogURL = designSystemURL.appendingPathComponent(".easel/catalog.json")
    let catalog = EaselDesignSystemCatalog(
      name: "Catalog System",
      summary: "Generated components",
      generatedAt: Date(timeIntervalSince1970: 0),
      componentGroups: [
        EaselDesignSystemComponentGroup(
          id: "buttons",
          title: "Buttons",
          summary: "Primary and secondary buttons",
          previewPath: "index.html#buttons",
          items: [
            EaselDesignSystemComponentItem(id: "primary", title: "Primary", summary: "Primary action")
          ]
        )
      ]
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(catalog).write(to: catalogURL, options: .atomic)

    let loadedCatalog = try await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory)
    #expect(loadedCatalog == catalog)
  }

  private func temporaryRoot(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
  }
}
