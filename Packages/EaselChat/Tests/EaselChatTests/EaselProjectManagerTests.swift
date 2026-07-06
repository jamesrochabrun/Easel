//
//  EaselProjectManagerTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

struct EaselProjectManagerTests {

  @Test
  func createProjectWritesFolderMetadataAndPreviewScaffold() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Hotel Booking Flow",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))

    #expect(project.name == "Hotel Booking Flow")
    #expect(project.kind == .prototype)
    #expect(project.workingDirectory.hasSuffix("/hotel-booking-flow"))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("README.md").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources", isDirectory: true).path))

    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)
    #expect(readme.contains("- Fidelity: High fidelity"))
    #expect(readme.contains("resources/codebase-references"))
    #expect(readme.contains("read-only context"))
    #expect(readme.contains("make all implementation changes inside this Easel project folder"))

    let metadataURL = projectURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("project.json")
    #expect(FileManager.default.fileExists(atPath: metadataURL.path))

    let packageURL = projectURL.appendingPathComponent("package.json")
    let packageData = try Data(contentsOf: packageURL)
    let package = try #require(JSONSerialization.jsonObject(with: packageData) as? [String: Any])
    let scripts = try #require(package["scripts"] as? [String: String])
    #expect(scripts["dev"]?.contains("http://localhost:") == true)

    let loadedProjects = try await manager.loadProjects()
    #expect(loadedProjects.count == 1)
    #expect(loadedProjects.first?.id == project.id)
    #expect(loadedProjects.first?.workingDirectory == project.workingDirectory)
    #expect(loadedProjects.first?.name == project.name)
  }

  @Test
  func createProjectUsesUniqueFoldersForDuplicateNames() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let request = EaselProjectCreateRequest(
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .wireframe
    )

    let first = try await manager.createProject(from: request)
    let second = try await manager.createProject(from: request)

    #expect(first.workingDirectory.hasSuffix("/roadmap-deck"))
    #expect(second.workingDirectory.hasSuffix("/roadmap-deck-2"))
  }

  @Test
  func createHighFidelityPrototypeStoresCodebasePath() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Checkout Flow",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      codebasePath: "/tmp/shop-app"
    ))

    let loadedProject = try #require(try await manager.loadProjects().first)
    #expect(project.codebasePath == "/tmp/shop-app")
    #expect(loadedProject.codebasePath == "/tmp/shop-app")
  }

  @Test
  func createNonHighFidelityProjectDropsCodebasePath() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Wireframe",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe,
      codebasePath: "/tmp/shop-app"
    ))

    #expect(project.codebasePath == nil)
  }

  @Test
  func createSlideDeckNormalizesFidelityAndOmitsFidelityFromReadme() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .wireframe
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)

    #expect(project.fidelity == .highFidelity)
    #expect(readme.contains("- Type: Slide deck"))
    #expect(readme.contains("- Fidelity:") == false)
    #expect(readme.contains("Slide deck layout:"))
    #expect(readme.contains("full-bleed"))
    #expect(readme.contains("no body padding"))
    #expect(readme.contains("Reusable slide template: `resources/SLIDE_TEMPLATE.md`"))
  }

  @Test
  func createSlideDeckWritesSlideScaffold() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let indexHTML = try String(contentsOf: projectURL.appendingPathComponent("index.html"), encoding: .utf8)
    let stageJS = try String(contentsOf: projectURL.appendingPathComponent("deck-stage.js"), encoding: .utf8)
    let templateURL = projectURL.appendingPathComponent("resources/SLIDE_TEMPLATE.md")
    let templateMarkdown = try String(contentsOf: templateURL, encoding: .utf8)

    #expect(indexHTML.contains("data-easel-deck"))
    #expect(indexHTML.contains("data-easel-slide"))
    #expect(indexHTML.contains("data-title=\"Opening\""))
    #expect(indexHTML.contains("easel-slide-safe"))
    #expect(indexHTML.contains("resources/SLIDE_TEMPLATE.md"))
    #expect(indexHTML.contains("<script src=\"./deck-stage.js\"></script>"))
    #expect(stageJS.contains("[data-easel-slide]"))
    #expect(stageJS.contains("ArrowRight"))
    #expect(templateMarkdown.contains("# Easel Slide Template"))
    #expect(templateMarkdown.contains("1280x720"))
    #expect(templateMarkdown.contains(".easel-slide-safe"))
  }

  @Test
  func createAnimationWritesTimelineScaffold() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Launch Motion",
      kind: .animation,
      designSystem: .none,
      fidelity: .wireframe,
      codebasePath: "/tmp/reference-app"
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let indexHTML = try String(contentsOf: projectURL.appendingPathComponent("index.html"), encoding: .utf8)
    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)
    let starterURL = projectURL.appendingPathComponent(AnimationScaffold.starterResourcePath)
    let starter = try String(contentsOf: starterURL, encoding: .utf8)
    let vendorDirectoryURL = projectURL.appendingPathComponent(AnimationScaffold.vendorDirectoryPath)

    #expect(project.fidelity == .highFidelity)
    #expect(project.codebasePath == nil)
    #expect(readme.contains("- Type: Animation"))
    #expect(readme.contains("- Fidelity:") == false)
    #expect(readme.contains("Animation starter: `resources/animations.jsx`"))
    #expect(readme.contains("resources/vendor/"))
    for fileName in AnimationScaffold.vendorFileNames {
      #expect(FileManager.default.fileExists(atPath: vendorDirectoryURL.appendingPathComponent(fileName).path))
    }
    #expect(indexHTML.contains("<script src=\"./resources/vendor/react.production.min.js\"></script>"))
    #expect(indexHTML.contains("<script src=\"./resources/vendor/react-dom.production.min.js\"></script>"))
    #expect(indexHTML.contains("<script src=\"./resources/vendor/babel.min.js\"></script>"))
    #expect(indexHTML.contains("Babel.registerPreset('react-classic'"))
    #expect(indexHTML.contains("<script type=\"text/babel\" data-presets=\"react-classic\" src=\"./resources/animations.jsx\"></script>"))
    #expect(indexHTML.contains("Preview failed to mount"))
    #expect(indexHTML.contains("function boot()"))
    #expect(indexHTML.contains("https://unpkg.com") == false)
    #expect(indexHTML.contains("const projectTitle = \"Launch Motion\";"))
    #expect(indexHTML.contains("const designSystemName = \"No design system\";"))
    #expect(indexHTML.contains("<Stage width={1280} height={720} duration={8}"))
    #expect(indexHTML.contains("#f6f4ef") == false)
    #expect(indexHTML.contains("#cc785c") == false)
    #expect(indexHTML.contains("Timeline-based motion\\\\n") == false)
    #expect(indexHTML.contains("starter-note") == false)
    #expect(starter.contains("@ds-adherence-ignore"))
    #expect(starter.contains("Object.assign(window"))
    #expect(starter.contains("Stage, PlaybackBar"))
    #expect(starter.contains("background = '#f8fafc'"))
    #expect(starter.contains("#f6f4ef") == false)
  }

  @Test
  func createPrototypeDoesNotWriteSlideRuntime() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Prototype",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)

    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("deck-stage.js").path) == false)
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/SLIDE_TEMPLATE.md").path) == false)
  }

  @Test
  func deleteProjectRemovesProjectFolder() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Delete Me",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))

    try await manager.deleteProject(project)

    #expect(FileManager.default.fileExists(atPath: project.workingDirectory) == false)
    let loadedProjects = try await manager.loadProjects()
    #expect(loadedProjects.isEmpty)
  }

  @Test
  func projectDecodingSupportsLegacyPresetDesignSystemValue() throws {
    let json = """
    {
      "createdAt": "2026-01-01T00:00:00Z",
      "designSystem": "material",
      "fidelity": "wireframe",
      "id": "00000000-0000-0000-0000-000000000001",
      "kind": "prototype",
      "name": "Legacy",
      "updatedAt": "2026-01-01T00:00:00Z",
      "workingDirectory": "/tmp/legacy"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let project = try decoder.decode(EaselDesignProject.self, from: Data(json.utf8))

    // The "material" preset was removed; legacy values now decode to none.
    #expect(project.designSystem == .preset(.none))
    #expect(project.designSystem.displayName == "No design system")
  }

  @Test
  func createProjectEmbedsCustomDesignSystemResourcePackIntoProject() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    // Stage a design system catalog on disk, as a real extraction would.
    let easelDirectory = designSystemDirectory.appendingPathComponent(".easel", isDirectory: true)
    let extractedAssetsDirectory = easelDirectory.appendingPathComponent("assets", isDirectory: true)
    let sourceCodeDirectory = designSystemDirectory.appendingPathComponent("resources/code", isDirectory: true)
    let sourceAssetsDirectory = designSystemDirectory.appendingPathComponent("resources/assets", isDirectory: true)
    try FileManager.default.createDirectory(at: easelDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: extractedAssetsDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sourceCodeDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sourceAssetsDirectory, withIntermediateDirectories: true)
    try Data("logo image".utf8).write(to: extractedAssetsDirectory.appendingPathComponent("logo.png"))
    try Data("example image".utf8).write(to: extractedAssetsDirectory.appendingPathComponent("example.png"))
    try Data("exported icon".utf8).write(to: sourceAssetsDirectory.appendingPathComponent("icon.svg"))
    try Data("export const Button = () => null".utf8).write(to: sourceCodeDirectory.appendingPathComponent("Button.tsx"))

    let buttonPreview = EaselDesignSystemPreviewScene(
      width: 200,
      height: 120,
      background: nil,
      layers: [
        EaselDesignSystemPreviewLayer(
          id: "button-image",
          kind: .image,
          x: 0,
          y: 0,
          width: 120,
          height: 60,
          imagePath: ".easel/assets/logo.png"
        ),
      ]
    )
    let examplePreview = EaselDesignSystemPreviewScene(
      width: 320,
      height: 200,
      background: nil,
      layers: [
        EaselDesignSystemPreviewLayer(
          id: "example-image",
          kind: .image,
          x: 0,
          y: 0,
          width: 320,
          height: 200,
          imagePath: ".easel/assets/example.png"
        ),
      ]
    )
    let catalog = EaselDesignSystemCatalog(
      name: "Plus UI",
      summary: "Local snapshot",
      generatedAt: nil,
      componentGroups: [],
      disclaimer: "Parsed locally from .fig.",
      tokens: EaselDesignSystemTokenSet(
        colors: [EaselDesignSystemColorToken(id: "c1", name: "Primary", hex: "#0055FF", sourceNodeID: nil, sourceNodeName: nil, confidence: 0.8)],
        typography: [],
        spacing: [],
        radii: [],
        effects: []
      ),
      componentFamilies: [
        EaselDesignSystemComponentFamily(
          id: "f1",
          title: "Button",
          category: "Buttons",
          summary: "Primary action",
          sourcePage: "Components",
          variantCount: 2,
          variantProperties: [
            EaselDesignSystemVariantProperty(id: "f1.state", name: "State", values: ["default", "hover"]),
          ],
          preview: buttonPreview,
          confidence: 0.9
        ),
      ],
      examples: [
        EaselDesignSystemExample(
          id: "screen-1",
          title: "Checkout",
          sourcePage: "Examples",
          preview: examplePreview
        ),
      ],
      assets: [
        EaselDesignSystemAsset(id: "logo", name: "Logo", relativePath: ".easel/assets/logo.png", kind: "image"),
      ],
      heroThumbnailPath: ".easel/assets/logo.png"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(catalog).write(to: easelDirectory.appendingPathComponent("catalog.json"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Plus UI",
      blurb: "Plus UI kit",
      notes: "Warm brand",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Landing Page",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let packURL = projectURL.appendingPathComponent("resources/design-system", isDirectory: true)
    let briefURL = packURL.appendingPathComponent("DESIGN.md")
    #expect(FileManager.default.fileExists(atPath: briefURL.path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("README.md").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("components.md").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("examples.md").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("assets.md").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("catalog.json").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("manifest.json").path))

    let brief = try String(contentsOf: briefURL, encoding: .utf8)
    #expect(brief.contains("# Design system: Plus UI"))
    #expect(brief.contains("#0055FF"))
    #expect(brief.contains("Button"))

    let catalogData = try Data(contentsOf: packURL.appendingPathComponent("catalog.json"))
    let embeddedCatalog = try JSONDecoder().decode(EaselDesignSystemCatalog.self, from: catalogData)
    #expect(embeddedCatalog.assets?.first?.relativePath == "resources/design-system/assets/extracted/logo.png")
    #expect(embeddedCatalog.heroThumbnailPath == "resources/design-system/assets/extracted/logo.png")
    #expect(embeddedCatalog.componentFamilies?.first?.preview?.layers.first?.imagePath == "resources/design-system/assets/extracted/logo.png")
    #expect(embeddedCatalog.examples?.first?.preview?.layers.first?.imagePath == "resources/design-system/assets/extracted/example.png")

    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/extracted/logo.png").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/extracted/example.png").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/imported/icon.svg").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/code/Button.tsx").path))

    let components = try String(contentsOf: packURL.appendingPathComponent("components.md"), encoding: .utf8)
    #expect(components.contains("## Button"))
    #expect(components.contains("State: default, hover"))
    #expect(components.contains("resources/design-system/assets/extracted/logo.png"))

    let examples = try String(contentsOf: packURL.appendingPathComponent("examples.md"), encoding: .utf8)
    #expect(examples.contains("## Checkout"))
    #expect(examples.contains("resources/design-system/assets/extracted/example.png"))

    let assets = try String(contentsOf: packURL.appendingPathComponent("assets.md"), encoding: .utf8)
    #expect(assets.contains("resources/design-system/assets/extracted/logo.png"))
    #expect(assets.contains("resources/design-system/assets/extracted/example.png"))
    #expect(assets.contains("resources/design-system/assets/imported/icon.svg"))

    let manifestData = try Data(contentsOf: packURL.appendingPathComponent("manifest.json"))
    let manifestDecoder = JSONDecoder()
    manifestDecoder.dateDecodingStrategy = .iso8601
    let manifest = try manifestDecoder.decode(DesignSystemResourcePackManifest.self, from: manifestData)
    #expect(manifest.designSystemName == "Plus UI")
    #expect(manifest.componentCount == 1)
    #expect(manifest.exampleCount == 1)
    #expect(manifest.assetCount == 3)
    #expect(manifest.codeExampleCount == 1)

    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)
    #expect(readme.contains("resources/design-system/DESIGN.md"))
    #expect(readme.contains("resources/design-system/components.md"))
    #expect(readme.contains("resources/design-system/assets.md"))
  }

  @Test
  func createProjectComponentsIndexOmitsLowSignalSingletonsFromNoisyCatalog() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    let easelDirectory = designSystemDirectory.appendingPathComponent(".easel", isDirectory: true)
    try FileManager.default.createDirectory(at: easelDirectory, withIntermediateDirectories: true)
    let screensDirectory = easelDirectory
      .appendingPathComponent("assets", isDirectory: true)
      .appendingPathComponent("screens", isDirectory: true)
    try FileManager.default.createDirectory(at: screensDirectory, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: screensDirectory.appendingPathComponent("checkout.png"))

    let screenPreview = EaselDesignSystemPreviewScene(
      width: 390,
      height: 844,
      background: "#FFFFFF",
      layers: [
        EaselDesignSystemPreviewLayer(
          id: "hero",
          kind: .image,
          x: 0,
          y: 0,
          width: 390,
          height: 240,
          imagePath: ".easel/assets/screens/checkout.png"
        ),
        EaselDesignSystemPreviewLayer(
          id: "hero-repeat",
          kind: .image,
          x: 0,
          y: 260,
          width: 390,
          height: 240,
          imagePath: ".easel/assets/screens/checkout.png"
        ),
      ]
    )
    let componentDocPreview = EaselDesignSystemPreviewScene(
      width: 320,
      height: 200,
      background: "#FFFFFF",
      layers: []
    )
    let catalog = EaselDesignSystemCatalog(
      name: "Noisy UI",
      summary: "Local snapshot",
      generatedAt: nil,
      componentGroups: [],
      componentFamilies: [
        EaselDesignSystemComponentFamily(
          id: "button",
          title: "Button",
          category: "Buttons",
          summary: "Action family",
          sourcePage: "Components",
          variantCount: 3,
          variantProperties: [
            EaselDesignSystemVariantProperty(id: "state", name: "State", values: ["Default", "Hover"]),
          ],
          confidence: 0.9
        ),
        EaselDesignSystemComponentFamily(
          id: "card",
          title: "Card (Vertical)",
          category: "Cards",
          summary: "Content surface",
          sourcePage: "Components",
          variantCount: 1,
          variantProperties: [],
          confidence: 0.8
        ),
        EaselDesignSystemComponentFamily(
          id: "state-default",
          title: "State=Default",
          category: "Components",
          summary: "Variant fragment",
          sourcePage: "Components",
          variantCount: 1,
          variantProperties: [
            EaselDesignSystemVariantProperty(id: "state", name: "State", values: ["Default"]),
          ],
          confidence: 0.7
        ),
        EaselDesignSystemComponentFamily(
          id: "arrow-right",
          title: "arrow right",
          category: "Components",
          summary: "Icon singleton",
          sourcePage: "Components",
          variantCount: 1,
          variantProperties: [],
          confidence: 0.7
        ),
      ],
      examples: [
        EaselDesignSystemExample(
          id: "checkout-screen",
          title: "Checkout Screen",
          sourcePage: "Examples",
          preview: screenPreview
        ),
        EaselDesignSystemExample(
          id: "button-doc",
          title: "Button",
          sourcePage: "Design System",
          preview: componentDocPreview
        ),
        EaselDesignSystemExample(
          id: "colors-doc",
          title: "Colors",
          sourcePage: "Design System",
          preview: nil
        ),
        EaselDesignSystemExample(
          id: "welcome-doc",
          title: "Welcome!",
          sourcePage: "Welcome",
          preview: nil
        ),
      ]
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(catalog).write(to: easelDirectory.appendingPathComponent("catalog.json"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Noisy UI",
      blurb: "Noisy UI kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Noisy Prototype",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let packURL = URL(fileURLWithPath: project.workingDirectory)
      .appendingPathComponent("resources/design-system", isDirectory: true)
    let components = try String(contentsOf: packURL.appendingPathComponent("components.md"), encoding: .utf8)
    #expect(components.contains("## Button"))
    #expect(components.contains("## Card (Vertical)"))
    #expect(components.contains("State=Default") == false)
    #expect(components.contains("arrow right") == false)
    #expect(components.contains("Omitted 2 low-signal one-off candidates"))

    let brief = try String(contentsOf: packURL.appendingPathComponent("DESIGN.md"), encoding: .utf8)
    #expect(brief.contains("Button"))
    #expect(brief.contains("Card (Vertical)"))
    #expect(brief.contains("State=Default") == false)
    #expect(brief.contains("arrow right") == false)

    let examples = try String(contentsOf: packURL.appendingPathComponent("examples.md"), encoding: .utf8)
    #expect(examples.contains("## Checkout Screen"))
    #expect(examples.contains("## Button") == false)
    #expect(examples.contains("## Colors") == false)
    #expect(examples.contains("## Welcome!") == false)
    #expect(examples.contains("Omitted 3 component documentation or foundation reference pages"))
    #expect(examples.components(separatedBy: "resources/design-system/assets/extracted/screens/checkout.png").count == 2)
  }

  @Test
  func createProjectWithCustomDesignSystemWithoutCatalogWritesEmptyIndexes() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    try FileManager.default.createDirectory(at: designSystemDirectory, withIntermediateDirectories: true)
    let designMarkdown = [
      "---",
      "version: alpha",
      "name: Bare System",
      "colors:",
      "  primary: \"#111111\"",
      "---",
      "",
      "## Overview",
      "",
      "A bare design system.",
    ].joined(separator: "\n")
    try Data(designMarkdown.utf8).write(to: designSystemDirectory.appendingPathComponent("DESIGN.md"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Bare System",
      blurb: "No generated catalog yet",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Bare Project",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let packURL = URL(fileURLWithPath: project.workingDirectory)
      .appendingPathComponent("resources/design-system", isDirectory: true)
    let components = try String(contentsOf: packURL.appendingPathComponent("components.md"), encoding: .utf8)
    let examples = try String(contentsOf: packURL.appendingPathComponent("examples.md"), encoding: .utf8)
    let assets = try String(contentsOf: packURL.appendingPathComponent("assets.md"), encoding: .utf8)

    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("DESIGN.md").path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("catalog.json").path))
    #expect(components.contains("No component families were available"))
    #expect(examples.contains("No example screens were available"))
    #expect(assets.contains("No reusable assets were available"))
  }

  @Test
  func createProjectWithMissingCustomDesignSystemDirectoryThrows() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let missingDirectory = rootDirectory.appendingPathComponent("missing-design-system", isDirectory: true)
    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Missing System",
      blurb: "Missing",
      notes: "",
      sourceLinks: [],
      workingDirectory: missingDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )
    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)

    await #expect(throws: EaselProjectManagerError.missingDesignSystemDirectory(missingDirectory.path)) {
      try await manager.createProject(from: EaselProjectCreateRequest(
        name: "Broken",
        kind: .prototype,
        designSystem: .custom(profile),
        fidelity: .highFidelity
      ))
    }
  }

  @Test
  func createProjectCopiesLooseAndGeneratedDesignSystemImagesIntoProject() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    // A prompt/markdown-authored design system: no catalog, but images the agent
    // generated into resources/ while building it, plus an imported asset.
    let resourcesDirectory = designSystemDirectory.appendingPathComponent("resources", isDirectory: true)
    let generatedImagesDirectory = resourcesDirectory.appendingPathComponent("images", isDirectory: true)
    let importedAssetsDirectory = resourcesDirectory.appendingPathComponent("assets", isDirectory: true)
    try FileManager.default.createDirectory(at: generatedImagesDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: importedAssetsDirectory, withIntermediateDirectories: true)
    try Data("hero image".utf8).write(to: resourcesDirectory.appendingPathComponent("hero.png"))
    try Data("texture image".utf8).write(to: generatedImagesDirectory.appendingPathComponent("texture.webp"))
    try Data("brand logo".utf8).write(to: importedAssetsDirectory.appendingPathComponent("logo.svg"))
    try Data("# Design system: Aurora".utf8).write(to: designSystemDirectory.appendingPathComponent("DESIGN.md"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Aurora",
      blurb: "Prompt-authored kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Aurora Landing",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let packURL = projectURL.appendingPathComponent("resources/design-system", isDirectory: true)

    // Generated images land under assets/generated, imported ones under assets/imported.
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/generated/hero.png").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/generated/images/texture.webp").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/design-system/assets/imported/logo.svg").path))

    let assets = try String(contentsOf: packURL.appendingPathComponent("assets.md"), encoding: .utf8)
    #expect(assets.contains("resources/design-system/assets/generated/hero.png"))
    #expect(assets.contains("resources/design-system/assets/generated/images/texture.webp"))
    #expect(assets.contains("resources/design-system/assets/imported/logo.svg"))
    #expect(assets.contains("Available assets (3 files)"))

    let manifestData = try Data(contentsOf: packURL.appendingPathComponent("manifest.json"))
    let manifestDecoder = JSONDecoder()
    manifestDecoder.dateDecodingStrategy = .iso8601
    let manifest = try manifestDecoder.decode(DesignSystemResourcePackManifest.self, from: manifestData)
    #expect(manifest.assetCount == 3)
  }

  @Test
  func refreshDesignSystemResourcesReembedsNewAssetsOnlyWhenSourceChanged() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    let resourcesDirectory = designSystemDirectory.appendingPathComponent("resources", isDirectory: true)
    try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
    try Data("hero image".utf8).write(to: resourcesDirectory.appendingPathComponent("hero.png"))
    try Data("# Design system: Aurora".utf8).write(to: designSystemDirectory.appendingPathComponent("DESIGN.md"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Aurora",
      blurb: "Prompt-authored kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Aurora Landing",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let packURL = projectURL.appendingPathComponent("resources/design-system", isDirectory: true)
    let manifestURL = packURL.appendingPathComponent("manifest.json")
    let newAssetInProject = packURL.appendingPathComponent("assets/generated/spotlight.png")

    // Nothing changed in the source: refresh is a no-op.
    let firstRefresh = try await manager.refreshDesignSystemResources(for: project)
    #expect(firstRefresh == false)
    #expect(FileManager.default.fileExists(atPath: newAssetInProject.path) == false)

    // Add a new generated image, then backdate the embedded pack so the source
    // counts as newer (this mirrors a design system that changed between opens
    // without relying on wall-clock timing in the test).
    try Data("spotlight image".utf8).write(to: resourcesDirectory.appendingPathComponent("spotlight.png"))
    try backdateResourcePackManifest(at: manifestURL)

    let secondRefresh = try await manager.refreshDesignSystemResources(for: project)
    #expect(secondRefresh == true)
    #expect(FileManager.default.fileExists(atPath: newAssetInProject.path))
    #expect(FileManager.default.fileExists(atPath: packURL.appendingPathComponent("assets/generated/hero.png").path))

    // The rewritten pack is now current, so refreshing again finds nothing new.
    let thirdRefresh = try await manager.refreshDesignSystemResources(for: project)
    #expect(thirdRefresh == false)
  }

  @Test
  func refreshDesignSystemResourcesBackfillsAssetsForOlderPackVersion() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    let resourcesDirectory = designSystemDirectory.appendingPathComponent("resources", isDirectory: true)
    try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
    try Data("hero image".utf8).write(to: resourcesDirectory.appendingPathComponent("hero.png"))
    try Data("# Design system: Aurora".utf8).write(to: designSystemDirectory.appendingPathComponent("DESIGN.md"))

    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: "Aurora",
      blurb: "Prompt-authored kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemDirectory.path,
      createdAt: Date(),
      updatedAt: Date()
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Aurora Landing",
      kind: .prototype,
      designSystem: .custom(profile),
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let packURL = projectURL.appendingPathComponent("resources/design-system", isDirectory: true)
    let heroInProject = packURL.appendingPathComponent("assets/generated/hero.png")

    // Simulate a pack written before the loose-image sweep existed: strip the
    // copied assets and remove the version stamp, mirroring a legacy pack.
    try FileManager.default.removeItem(at: packURL.appendingPathComponent("assets"))
    try stripResourcePackVersion(at: packURL.appendingPathComponent("manifest.json"))
    #expect(FileManager.default.fileExists(atPath: heroInProject.path) == false)

    // Opening the project re-embeds the pack even though the source is unchanged.
    let didRefresh = try await manager.refreshDesignSystemResources(for: project)
    #expect(didRefresh == true)
    #expect(FileManager.default.fileExists(atPath: heroInProject.path))
  }

  /// Removes the `packVersion` field so the manifest looks like a legacy pack.
  private func stripResourcePackVersion(at manifestURL: URL) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var manifest = try decoder.decode(DesignSystemResourcePackManifest.self, from: Data(contentsOf: manifestURL))
    manifest.packVersion = nil
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(manifest).write(to: manifestURL)
  }

  /// Rewrites a pack manifest's `embeddedAt` to the distant past so the source
  /// design system is treated as newer on the next refresh.
  private func backdateResourcePackManifest(at manifestURL: URL) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let original = try decoder.decode(DesignSystemResourcePackManifest.self, from: Data(contentsOf: manifestURL))
    let backdated = DesignSystemResourcePackManifest(
      designSystemID: original.designSystemID,
      designSystemName: original.designSystemName,
      embeddedAt: Date(timeIntervalSince1970: 0),
      sourceWorkingDirectory: original.sourceWorkingDirectory,
      entryPoints: original.entryPoints,
      componentCount: original.componentCount,
      exampleCount: original.exampleCount,
      assetCount: original.assetCount,
      codeExampleCount: original.codeExampleCount,
      sourceCatalogGeneratedAt: original.sourceCatalogGeneratedAt,
      packVersion: original.packVersion
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(backdated).write(to: manifestURL)
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselProjectManagerTests-\(UUID().uuidString)", isDirectory: true)
  }
}
