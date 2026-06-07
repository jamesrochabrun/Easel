//
//  EaselDesignSystemManagerTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

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
    let indexURL = designSystemURL.appendingPathComponent("index.html")
    #expect(FileManager.default.fileExists(atPath: indexURL.path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("README.md").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("package.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent(".easel/design-system.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent(".easel/catalog.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/App.swift").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/node_modules/ignored.js").path) == false)
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/figma/Brand.fig").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/assets/logo.png").path))

    let indexHTML = try String(contentsOf: indexURL, encoding: .utf8)
    #expect(indexHTML.contains(EaselDesignSystemCatalogTemplate.marker))
    #expect(indexHTML.contains("fetch(\".easel/catalog.json\""))
    #expect(indexHTML.contains("Codex will replace this scaffold") == false)

    let placeholderCatalog = try await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory)
    #expect(placeholderCatalog?.schemaVersion == 3)
    #expect(placeholderCatalog?.name == profile.name)
    #expect(placeholderCatalog?.sections.isEmpty == true)
    #expect(placeholderCatalog?.hasTokenContent == false)

    let loadedSystems = try await manager.loadDesignSystems()
    #expect(loadedSystems.map(\.id) == [profile.id])
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
          sourcePath: "resources/code/Button.swift",
          items: [
            EaselDesignSystemComponentItem(
              id: "primary",
              title: "Primary",
              summary: "Primary action",
              previewPath: "resources/previews/primary.png",
              sourcePath: "resources/code/PrimaryButton.swift"
            )
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

  @Test
  func loadDesignSystemsRepairsLegacyIndexWithBackup() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemTemplateRepairTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Repairable System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))
    let designSystemURL = URL(fileURLWithPath: profile.workingDirectory)
    let indexURL = designSystemURL.appendingPathComponent("index.html")
    try Data("<html><body>Legacy generated catalog</body></html>".utf8)
      .write(to: indexURL, options: .atomic)

    _ = try await manager.loadDesignSystems()

    let repairedHTML = try String(contentsOf: indexURL, encoding: .utf8)
    let backupHTML = try String(
      contentsOf: designSystemURL.appendingPathComponent(".easel/index.previous.html"),
      encoding: .utf8
    )
    #expect(repairedHTML.contains(EaselDesignSystemCatalogTemplate.marker))
    #expect(backupHTML.contains("Legacy generated catalog"))
  }

  @Test
  func loadCatalogDecodesSectionSchemaAndFlattensGroupsForCompatibility() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemSchemaTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Schema System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))
    let catalogURL = URL(fileURLWithPath: profile.workingDirectory)
      .appendingPathComponent(".easel/catalog.json")
    let json = """
    {
      "schemaVersion": 2,
      "name": "Schema System",
      "summary": "Sectioned catalog",
      "generatedAt": "1970-01-01T00:00:00Z",
      "sections": [
        {
          "id": "foundations",
          "title": "Foundations",
          "summary": "Color, type, and spacing",
          "groups": [
            {
              "id": "color-system",
              "title": "Color System",
              "summary": "Brand and status colors",
              "previewPath": "resources/previews/colors.svg",
              "sourcePath": "index.html#color-system",
              "items": []
            }
          ]
        }
      ]
    }
    """
    try Data(json.utf8).write(to: catalogURL, options: .atomic)

    let loadedCatalog = try #require(await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory))

    #expect(loadedCatalog.schemaVersion == 2)
    #expect(loadedCatalog.sections.map(\.title) == ["Foundations"])
    #expect(loadedCatalog.componentGroups.map(\.title) == ["Color System"])
    #expect(loadedCatalog.displaySections.map(\.title) == ["Foundations"])
  }

  @Test
  func startingPointBuildsPromptContextFromCatalogItem() async throws {
    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "AgentHub Design System",
      blurb: "AgentHub product UI",
      notes: "Dense macOS shell",
      sourceLinks: [],
      workingDirectory: "/tmp/agenthub-design-system",
      createdAt: Date(),
      updatedAt: Date()
    )
    let catalog = EaselDesignSystemCatalog(
      name: "AgentHub Design System",
      summary: "Generated components",
      generatedAt: nil,
      componentGroups: []
    )
    let group = EaselDesignSystemComponentGroup(
      id: "buttons",
      title: "Button styles",
      summary: "Primary and outline buttons",
      previewPath: "resources/previews/buttons.png",
      sourcePath: "resources/code/Button.swift",
      items: []
    )
    let item = EaselDesignSystemComponentItem(
      id: "primary",
      title: "Primary button",
      summary: "Main action button",
      sourcePath: "resources/code/PrimaryButton.swift"
    )

    let startingPoint = EaselDesignSystemStartingPoint.item(
      designSystem: .custom(profile),
      catalog: catalog,
      group: group,
      item: item
    )

    #expect(startingPoint.displayTitle == "Primary button")
    #expect(startingPoint.promptContext.contains("Design system: AgentHub Design System"))
    #expect(startingPoint.promptContext.contains("Source path: resources/code/PrimaryButton.swift"))
  }

  @Test
  func loadCatalogDecodesTokenSchema() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemTokenTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Token System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))
    let catalogURL = URL(fileURLWithPath: profile.workingDirectory)
      .appendingPathComponent(".easel/catalog.json")
    let json = """
    {
      "schemaVersion": 3,
      "name": "Token System",
      "summary": "Primitive tokens",
      "colors": [
        { "id": "brand-primary", "name": "Primary", "group": "Brand", "value": "#0E7C66", "onColor": "#FFFFFF" }
      ],
      "typography": {
        "fonts": [ { "role": "Sans", "family": "Inter", "stack": "Inter, system-ui, sans-serif" } ],
        "styles": [ { "id": "display", "name": "Display", "fontRole": "Sans", "size": 48, "weight": 700, "lineHeight": 1.05 } ]
      },
      "spacing": [ { "id": "sp-4", "name": "4", "value": 16 } ],
      "radii": [ { "id": "rad-md", "name": "md", "value": 8 } ],
      "elevation": [ { "id": "level-1", "name": "Level 1", "shadow": "0 1px 2px rgba(16,24,40,0.06)", "usage": "Resting cards" } ],
      "states": [ { "id": "hover", "name": "Hover", "background": "#F2F4F7", "foreground": "#101828" } ],
      "icons": [ { "id": "search", "name": "search", "svg": "<path d=\\"M5 5l4 4\\"/>" } ],
      "components": [
        {
          "id": "buttons",
          "kind": "button",
          "name": "Buttons",
          "summary": "Primary actions",
          "variants": [
            { "name": "Primary", "label": "Get started", "background": "#0E7C66", "foreground": "#FFFFFF", "radius": 8,
              "states": { "disabled": { "background": "#D0D5DD", "foreground": "#98A2B3" } } }
          ]
        }
      ]
    }
    """
    try Data(json.utf8).write(to: catalogURL, options: .atomic)

    let loaded = try #require(await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory))

    #expect(loaded.schemaVersion == 3)
    #expect(loaded.hasTokenContent == true)
    #expect(loaded.colors.map(\.name) == ["Primary"])
    #expect(loaded.colors.first?.value == "#0E7C66")
    #expect(loaded.typography?.styles.map(\.name) == ["Display"])
    #expect(loaded.typography?.styles.first?.size == 48)
    #expect(loaded.spacing.first?.value == 16)
    #expect(loaded.radii.first?.value == 8)
    #expect(loaded.elevation.first?.shadow == "0 1px 2px rgba(16,24,40,0.06)")
    #expect(loaded.states.map(\.name) == ["Hover"])
    #expect(loaded.icons.map(\.name) == ["search"])
    #expect(loaded.components.first?.kind == "button")
    #expect(loaded.components.first?.variants.first?.label == "Get started")
    #expect(loaded.components.first?.variants.first?.states?["disabled"]?.background == "#D0D5DD")
  }

  @Test
  func browsableGroupsSynthesizeFromTokens() {
    let catalog = EaselDesignSystemCatalog(
      schemaVersion: 3,
      name: "Token System",
      summary: "Primitive tokens",
      generatedAt: nil,
      colors: [EaselDesignColorToken(name: "Primary", value: "#0E7C66")],
      typography: EaselDesignTypography(styles: [EaselDesignTypeStyle(name: "Display", size: 48)]),
      spacing: [EaselDesignScaleToken(name: "4", value: 16)],
      elevation: [EaselDesignElevationToken(name: "Level 1", shadow: "0 1px 2px rgba(0,0,0,0.1)")],
      components: [
        EaselDesignSystemComponentSpec(
          id: "buttons",
          kind: "button",
          name: "Buttons",
          variants: [EaselDesignSystemComponentVariant(name: "Primary", label: "Go")]
        )
      ]
    )

    let titles = catalog.browsableGroups.map(\.title)
    #expect(titles == ["Colors", "Typography", "Spacing", "Elevation", "Buttons"])

    let buttonsGroup = catalog.browsableGroups.first { $0.id == "buttons" }
    #expect(buttonsGroup?.items.map(\.title) == ["Primary"])
  }

  @Test
  func deleteDesignSystemRemovesFolderAndDropsItFromLoad() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemDeleteTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Deletable System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))

    let directoryURL = URL(fileURLWithPath: profile.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: directoryURL.path))

    try await manager.deleteDesignSystem(profile)

    #expect(FileManager.default.fileExists(atPath: directoryURL.path) == false)
    let remaining = try await manager.loadDesignSystems()
    #expect(remaining.contains { $0.id == profile.id } == false)
  }

  @Test
  func deleteDesignSystemThrowsWhenDirectoryMissing() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemDeleteMissingTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let ghost = EaselDesignSystemProfile(
      id: UUID(),
      name: "Ghost",
      blurb: "",
      notes: "",
      sourceLinks: [],
      workingDirectory: rootDirectory.appendingPathComponent("does-not-exist").path,
      createdAt: Date(),
      updatedAt: Date()
    )

    await #expect(throws: EaselDesignSystemManagerError.self) {
      try await manager.deleteDesignSystem(ghost)
    }
  }

  @Test
  func browsableGroupsFallBackToLegacyComponentGroups() {
    let catalog = EaselDesignSystemCatalog(
      name: "Legacy System",
      summary: "Sectioned",
      generatedAt: nil,
      componentGroups: [
        EaselDesignSystemComponentGroup(id: "buttons", title: "Buttons", summary: "", previewPath: nil, items: [])
      ]
    )

    #expect(catalog.hasTokenContent == false)
    #expect(catalog.browsableGroups.map(\.title) == ["Buttons"])
  }

  private func temporaryRoot(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
  }
}
