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
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("README.md").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("package.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent(".easel/design-system.json").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/App.swift").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/code/Frontend/node_modules/ignored.js").path) == false)
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/figma/Brand.fig").path))
    #expect(FileManager.default.fileExists(atPath: designSystemURL.appendingPathComponent("resources/assets/logo.png").path))

    let indexHTML = try String(contentsOf: designSystemURL.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(indexHTML.contains(".easel/catalog.json"))
    #expect(indexHTML.contains("Codex will replace this scaffold") == false)

    let loadedSystems = try await manager.loadDesignSystems()
    #expect(loadedSystems.map(\.id) == [profile.id])
  }

  @Test
  func createDesignSystemPassesCopiedFigFilesToImporter() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemImporterWiringTests")
    let sourceDirectory = temporaryRoot(named: "DesignSystemImporterSourceTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: sourceDirectory)
    }

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    let figURL = sourceDirectory.appendingPathComponent("System.fig")
    try Data([0, 1, 2]).write(to: figURL)

    let importer = RecordingDesignSystemImporter()
    let manager = LocalEaselDesignSystemManager(
      rootDirectory: rootDirectory,
      designSystemImporter: importer,
      importScheduling: .immediate
    )

    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "AgentHub Design System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [figURL],
      figImportMode: .extractCatalog,
      assetURLs: [],
      notes: ""
    ))

    let requests = await importer.requests
    let request = try #require(requests.first)
    #expect(request.profile.id == profile.id)
    #expect(request.importMode == .extractCatalog)
    #expect(request.figFileURLs.map(\.lastPathComponent) == ["System.fig"])
    #expect(request.figFileURLs.first?.path.hasPrefix(profile.workingDirectory) == true)
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

  @Test
  func referenceImportWritesManifestWithoutParsingFigFile() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemReferenceImportTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let figURL = rootDirectory.appendingPathComponent("Reference.fig")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: figURL)

    let profile = makeProfile(workingDirectory: rootDirectory.path)
    let importer = LocalEaselDesignSystemImporter(parser: FailingFigFileParser())
    let result = await importer.importDesignSystemResources(EaselDesignSystemImportRequest(
      profile: profile,
      directoryURL: rootDirectory,
      figFileURLs: [figURL],
      importMode: .reference
    ))

    let manifest = try #require(result.manifest)
    let source = try #require(manifest.sources.first)
    #expect(source.status == .skipped)
    #expect(manifest.importMode == .reference)
    #expect(manifest.components.isEmpty)
    #expect(result.catalog?.componentGroups.isEmpty == true)
    #expect(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(".easel/design-system-manifest.json").path))
  }

  @Test
  func extractImportWritesManifestCatalogAndRawCache() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemExtractImportTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let figURL = rootDirectory.appendingPathComponent("Brand.fig")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try Data([4, 5, 6]).write(to: figURL)

    let document = EaselParsedFigDocument(
      parser: EaselParsedFigParser(name: "fixture-parser", version: "1.0"),
      document: EaselParsedFigDocumentInfo(nodeCount: 5, pageCount: 1),
      nodes: [
        EaselParsedFigNode(
          id: "1:1",
          type: "CANVAS",
          name: "Components",
          parentID: nil,
          pageName: "Components",
          depth: 0,
          width: nil,
          height: nil,
          childCount: 2,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "2:1",
          type: "COMPONENT",
          name: "Button / Primary",
          parentID: "1:1",
          pageName: "Components",
          depth: 1,
          width: 120,
          height: 44,
          childCount: 1,
          fillColors: ["#0055FF"],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: 8,
          effectTypes: ["DROP_SHADOW"]
        ),
        EaselParsedFigNode(
          id: "2:2",
          type: "TEXT",
          name: "Label",
          parentID: "2:1",
          pageName: "Components",
          depth: 2,
          width: 80,
          height: 20,
          childCount: 0,
          fillColors: [],
          strokeColors: [],
          fontFamily: "Inter",
          fontStyle: "Semi Bold",
          fontSize: 16,
          text: "Continue",
          cornerRadius: nil,
          effectTypes: []
        ),
      ]
    )
    let importer = LocalEaselDesignSystemImporter(parser: FixtureFigFileParser(document: document))
    let result = await importer.importDesignSystemResources(EaselDesignSystemImportRequest(
      profile: makeProfile(workingDirectory: rootDirectory.path),
      directoryURL: rootDirectory,
      figFileURLs: [figURL],
      importMode: .extractCatalog
    ))

    let manifest = try #require(result.manifest)
    #expect(manifest.sources.first?.status == .parsed)
    #expect(manifest.tokens.colors.map(\.hex).contains("#0055FF"))
    #expect(manifest.tokens.typography.map(\.fontFamily).contains("Inter"))
    #expect(manifest.components.map(\.title).contains("Button / Primary"))

    let catalog = try #require(result.catalog)
    #expect(catalog.componentGroups.first?.title == "Buttons")
    #expect(catalog.componentGroups.first?.items.first?.title == "Button / Primary")
    #expect(catalog.isReference)
    #expect(catalog.disclaimer == EaselDesignSystemCatalog.localFigDisclaimer)
    #expect(catalog.hasReferenceContent)
    #expect(catalog.tokens?.colors.map(\.hex).contains("#0055FF") == true)
    #expect(catalog.tokens?.typography.map(\.fontFamily).contains("Inter") == true)
    #expect(catalog.componentFamilies?.map(\.title).contains("Button / Primary") == true)
    #expect(catalog.sourceDiagnostics?.parsedCount == 1)
    #expect(catalog.sourceDiagnostics?.parserName == "fixture-parser")
    #expect(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(".easel/imports").path))

    let indexHTML = try String(contentsOf: rootDirectory.appendingPathComponent("index.html"), encoding: .utf8)
    #expect(indexHTML.contains(".easel/catalog.json"))
    #expect(indexHTML.contains("Codex will replace this scaffold") == false)
  }

  @Test
  func figParserFindsNVMExecutableWhenPathIsMinimal() throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemExecutableLookupTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let homeDirectory = rootDirectory.appendingPathComponent("home", isDirectory: true)
    let nvmBinDirectory = homeDirectory
      .appendingPathComponent(".nvm/versions/node/v22.16.0/bin", isDirectory: true)
    try FileManager.default.createDirectory(at: nvmBinDirectory, withIntermediateDirectories: true)

    let executableURL = nvmBinDirectory.appendingPathComponent("fake-npm")
    try Data("#!/bin/sh\n".utf8).write(to: executableURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

    let resolvedURL = try NodeEaselFigFileParser.resolvedExecutableURL(
      named: "fake-npm",
      environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
      homeDirectory: homeDirectory
    )

    #expect(resolvedURL == executableURL.standardizedFileURL)
  }

  @Test
  func figParserReportsMissingExecutable() throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemMissingExecutableTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    do {
      _ = try NodeEaselFigFileParser.resolvedExecutableURL(
        named: "definitely-not-node",
        environment: ["PATH": ""],
        homeDirectory: rootDirectory
      )
      Issue.record("Expected executable lookup to fail")
    } catch let error as EaselFigParserError {
      #expect(error.localizedDescription.contains("definitely-not-node"))
    }
  }

  @Test
  func extractImportDeduplicatesInternalComponentCandidates() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemInternalCandidateTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let figURL = rootDirectory.appendingPathComponent("System.fig")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try Data([7, 8, 9]).write(to: figURL)

    let document = EaselParsedFigDocument(
      parser: EaselParsedFigParser(name: "fixture-parser", version: "1.0"),
      document: EaselParsedFigDocumentInfo(nodeCount: 4, pageCount: 2),
      nodes: [
        EaselParsedFigNode(
          id: "1:1",
          type: "SYMBOL",
          name: "Button/Primary",
          parentID: nil,
          pageName: "Internal Only Canvas",
          depth: 1,
          width: 120,
          height: 44,
          childCount: 2,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "1:2",
          type: "SYMBOL",
          name: "Button/Primary",
          parentID: nil,
          pageName: "Internal Only Canvas",
          depth: 1,
          width: 120,
          height: 44,
          childCount: 2,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "2:1",
          type: "FRAME",
          name: "Internal Scratch",
          parentID: nil,
          pageName: "Internal Only Canvas",
          depth: 1,
          width: 800,
          height: 600,
          childCount: 4,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "2:2",
          type: "FRAME",
          name: "Marketing Landing Page",
          parentID: nil,
          pageName: "Examples",
          depth: 1,
          width: 1200,
          height: 900,
          childCount: 8,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
      ]
    )
    let importer = LocalEaselDesignSystemImporter(parser: FixtureFigFileParser(document: document))
    let result = await importer.importDesignSystemResources(EaselDesignSystemImportRequest(
      profile: makeProfile(workingDirectory: rootDirectory.path),
      directoryURL: rootDirectory,
      figFileURLs: [figURL],
      importMode: .extractCatalog
    ))

    let manifest = try #require(result.manifest)
    #expect(manifest.components.map(\.title) == ["Button / Primary"])
    #expect(manifest.components.first?.summary == "Button family with 2 variants from local Figma components.")
    #expect(manifest.references.map(\.title) == ["Marketing Landing Page"])
    #expect(manifest.summary.contains("Local snapshot"))
    #expect(manifest.summary.contains("1 component family"))
  }

  @Test
  func extractImportCollapsesFigmaVariantPropertyNamesIntoFamilies() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemVariantFamilyTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let figURL = rootDirectory.appendingPathComponent("System.fig")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try Data([10, 11, 12]).write(to: figURL)

    let document = EaselParsedFigDocument(
      parser: EaselParsedFigParser(name: "fixture-parser", version: "1.0"),
      document: EaselParsedFigDocumentInfo(nodeCount: 4, pageCount: 1),
      nodes: [
        EaselParsedFigNode(
          id: "1:1",
          type: "FRAME",
          name: "Button",
          parentID: nil,
          pageName: "Button",
          depth: 2,
          width: 800,
          height: 320,
          childCount: 2,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "1:2",
          type: "SYMBOL",
          name: "Kind=filled, Status=primary, State=default, Size=sm",
          parentID: "1:1",
          pageName: "Button",
          depth: 3,
          width: 120,
          height: 36,
          childCount: 3,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
        EaselParsedFigNode(
          id: "1:3",
          type: "SYMBOL",
          name: "Kind=outlined, Status=default, State=hovered, Size=lg",
          parentID: "1:1",
          pageName: "Button",
          depth: 3,
          width: 160,
          height: 44,
          childCount: 3,
          fillColors: [],
          strokeColors: [],
          fontFamily: nil,
          fontStyle: nil,
          fontSize: nil,
          text: nil,
          cornerRadius: nil,
          effectTypes: []
        ),
      ]
    )
    let importer = LocalEaselDesignSystemImporter(parser: FixtureFigFileParser(document: document))
    let result = await importer.importDesignSystemResources(EaselDesignSystemImportRequest(
      profile: makeProfile(workingDirectory: rootDirectory.path),
      directoryURL: rootDirectory,
      figFileURLs: [figURL],
      importMode: .extractCatalog
    ))

    let manifest = try #require(result.manifest)
    #expect(manifest.components.map(\.title) == ["Button"])
    #expect(manifest.components.first?.summary == "Button family with 2 variants.")

    let catalog = try #require(result.catalog)
    #expect(catalog.componentGroups.first?.items.map(\.title) == ["Button"])

    let family = try #require(catalog.componentFamilies?.first)
    let propertyNames = family.variantProperties.map(\.name)
    #expect(propertyNames.contains("Kind"))
    #expect(propertyNames.contains("Size"))
    let kind = try #require(family.variantProperties.first { $0.name == "Kind" })
    #expect(kind.values.sorted() == ["filled", "outlined"])
  }

  @Test
  func parseVariantPropertiesExtractsOrderedPairs() {
    let pairs = EaselDesignSystemManifestNormalizer.parseVariantProperties(
      "Kind=filled, Status=primary, Size=sm"
    )
    #expect(pairs.map(\.name) == ["Kind", "Status", "Size"])
    #expect(pairs.map(\.value) == ["filled", "primary", "sm"])
    #expect(EaselDesignSystemManifestNormalizer.parseVariantProperties("Button / Primary").isEmpty)
  }

  @Test
  func extractImportSynthesizesPreviewScenesAssetsAndHero() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemPreviewSceneTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let figURL = rootDirectory.appendingPathComponent("System.fig")
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try Data([13, 14, 15]).write(to: figURL)

    let document = EaselParsedFigDocument(
      parser: EaselParsedFigParser(name: "fixture-parser", version: "1.0"),
      document: EaselParsedFigDocumentInfo(
        nodeCount: 6,
        pageCount: 1,
        thumbnailPath: "thumbnail.png",
        imageAssets: [EaselParsedFigImageAsset(name: "logo", path: "images/logo.png")]
      ),
      nodes: [
        EaselParsedFigNode(
          id: "10:1", type: "COMPONENT", name: "Card", parentID: nil, pageName: "Components",
          depth: 1, x: 0, y: 0, width: 240, height: 160, childCount: 3,
          fillColors: ["#FFFFFF"], strokeColors: [], fontFamily: nil, fontStyle: nil,
          fontSize: nil, text: nil, cornerRadius: 12, effectTypes: []
        ),
        EaselParsedFigNode(
          id: "10:2", type: "RECTANGLE", name: "Header", parentID: "10:1", pageName: "Components",
          depth: 2, x: 0, y: 0, width: 240, height: 60, childCount: 0,
          fillColors: ["#0055FF"], strokeColors: [], fontFamily: nil, fontStyle: nil,
          fontSize: nil, text: nil, cornerRadius: nil, effectTypes: []
        ),
        EaselParsedFigNode(
          id: "10:3", type: "TEXT", name: "Title", parentID: "10:1", pageName: "Components",
          depth: 2, x: 16, y: 80, width: 200, height: 24, childCount: 0,
          fillColors: ["#111111"], strokeColors: [], fontFamily: "Inter", fontStyle: "Semi Bold",
          fontSize: 18, text: "Card title", cornerRadius: nil, effectTypes: []
        ),
        EaselParsedFigNode(
          id: "10:4", type: "RECTANGLE", name: "Avatar", parentID: "10:1", pageName: "Components",
          depth: 2, x: 16, y: 16, width: 28, height: 28, childCount: 0,
          fillColors: [], strokeColors: [], fontFamily: nil, fontStyle: nil,
          fontSize: nil, text: nil, cornerRadius: nil, effectTypes: [], imageRef: "images/logo.png"
        ),
        EaselParsedFigNode(
          id: "20:1", type: "FRAME", name: "Dashboard Screen", parentID: nil, pageName: "Examples",
          depth: 1, x: 0, y: 0, width: 1200, height: 800, childCount: 1,
          fillColors: ["#F5F5F5"], strokeColors: [], fontFamily: nil, fontStyle: nil,
          fontSize: nil, text: nil, cornerRadius: nil, effectTypes: []
        ),
        EaselParsedFigNode(
          id: "20:2", type: "RECTANGLE", name: "Sidebar", parentID: "20:1", pageName: "Examples",
          depth: 2, x: 0, y: 0, width: 240, height: 800, childCount: 0,
          fillColors: ["#FFFFFF"], strokeColors: [], fontFamily: nil, fontStyle: nil,
          fontSize: nil, text: nil, cornerRadius: nil, effectTypes: []
        ),
      ]
    )

    let importer = LocalEaselDesignSystemImporter(parser: FixtureFigFileParser(document: document))
    let result = await importer.importDesignSystemResources(EaselDesignSystemImportRequest(
      profile: makeProfile(workingDirectory: rootDirectory.path),
      directoryURL: rootDirectory,
      figFileURLs: [figURL],
      importMode: .extractCatalog
    ))

    let catalog = try #require(result.catalog)
    #expect(catalog.heroThumbnailPath == ".easel/assets/thumbnail.png")
    #expect(catalog.assets?.contains { $0.relativePath == ".easel/assets/images/logo.png" } == true)

    let card = try #require(catalog.componentFamilies?.first { $0.title == "Card" })
    let scene = try #require(card.preview)
    #expect(scene.width == 240)
    #expect(scene.height == 160)
    #expect(scene.layers.contains { $0.kind == .image && $0.imagePath == ".easel/assets/images/logo.png" })
    #expect(scene.layers.contains { $0.kind == .text && $0.text == "Card title" })

    let example = try #require(catalog.examples?.first { $0.title == "Dashboard Screen" })
    #expect(example.preview?.layers.isEmpty == false)
  }

  @Test
  func deleteDesignSystemRemovesManagedDirectory() async throws {
    let rootDirectory = temporaryRoot(named: "DesignSystemDeleteTests")
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: rootDirectory)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "Brand System",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: ""
    ))
    let designSystemURL = URL(fileURLWithPath: profile.workingDirectory)

    #expect(FileManager.default.fileExists(atPath: designSystemURL.path))

    try await manager.deleteDesignSystem(profile)

    #expect(FileManager.default.fileExists(atPath: designSystemURL.path) == false)
    #expect(try await manager.loadDesignSystems().isEmpty)
  }

  private func temporaryRoot(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
  }

  private func makeProfile(workingDirectory: String) -> EaselDesignSystemProfile {
    EaselDesignSystemProfile(
      id: UUID(),
      name: "Brand System",
      blurb: "Brand System components",
      notes: "",
      sourceLinks: [],
      workingDirectory: workingDirectory,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}

private actor RecordingDesignSystemImporter: EaselDesignSystemImporting {
  private(set) var requests: [EaselDesignSystemImportRequest] = []

  func importDesignSystemResources(_ request: EaselDesignSystemImportRequest) async -> EaselDesignSystemImportResult {
    requests.append(request)
    return EaselDesignSystemImportResult(manifest: nil, catalog: nil)
  }
}

private struct FixtureFigFileParser: EaselFigFileParsing {
  let document: EaselParsedFigDocument

  func parseFigFile(at url: URL, assetsDirectory: URL?) async throws -> EaselParsedFigDocument {
    document
  }
}

private struct FailingFigFileParser: EaselFigFileParsing {
  func parseFigFile(at url: URL, assetsDirectory: URL?) async throws -> EaselParsedFigDocument {
    throw NSError(domain: "FailingFigFileParser", code: 1)
  }
}
