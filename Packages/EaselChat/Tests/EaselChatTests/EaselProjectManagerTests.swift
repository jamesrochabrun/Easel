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
  func createProjectCopiesCustomDesignSystemBriefIntoProject() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemDirectory = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemDirectory)
    }

    // Stage a design system catalog on disk, as a real extraction would.
    let easelDirectory = designSystemDirectory.appendingPathComponent(".easel", isDirectory: true)
    try FileManager.default.createDirectory(at: easelDirectory, withIntermediateDirectories: true)
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
        EaselDesignSystemComponentFamily(id: "f1", title: "Button", category: "Buttons", summary: "", sourcePage: nil, variantCount: 2, variantProperties: [], confidence: 0.9)
      ]
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
    let briefURL = projectURL.appendingPathComponent("resources/design-system/DESIGN.md")
    #expect(FileManager.default.fileExists(atPath: briefURL.path))

    let brief = try String(contentsOf: briefURL, encoding: .utf8)
    #expect(brief.contains("# Design system: Plus UI"))
    #expect(brief.contains("#0055FF"))
    #expect(brief.contains("Button"))

    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)
    #expect(readme.contains("resources/design-system/DESIGN.md"))
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselProjectManagerTests-\(UUID().uuidString)", isDirectory: true)
  }
}
