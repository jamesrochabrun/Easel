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
      designSystem: .airbnb,
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
    #expect(readme.contains("- Design systems: Airbnb Design System"))

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
      designSystem: .apple,
      fidelity: .wireframe
    )

    let first = try await manager.createProject(from: request)
    let second = try await manager.createProject(from: request)

    #expect(first.workingDirectory.hasSuffix("/roadmap-deck"))
    #expect(second.workingDirectory.hasSuffix("/roadmap-deck-2"))
  }

  @Test
  func createSlideDeckNormalizesFidelityAndOmitsFidelityFromReadme() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .apple,
      fidelity: .wireframe
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let readme = try String(contentsOf: projectURL.appendingPathComponent("README.md"), encoding: .utf8)

    #expect(project.fidelity == .highFidelity)
    #expect(readme.contains("- Type: Slide deck"))
    #expect(readme.contains("- Fidelity:") == false)
  }

  @Test
  func createSlideDeckWritesSlideScaffold() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .apple,
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let indexHTML = try String(contentsOf: projectURL.appendingPathComponent("index.html"), encoding: .utf8)
    let stageJS = try String(contentsOf: projectURL.appendingPathComponent("deck-stage.js"), encoding: .utf8)

    #expect(indexHTML.contains("data-easel-deck"))
    #expect(indexHTML.contains("data-easel-slide"))
    #expect(indexHTML.contains("data-title=\"Opening\""))
    #expect(indexHTML.contains("<script src=\"./deck-stage.js\"></script>"))
    #expect(stageJS.contains("[data-easel-slide]"))
    #expect(stageJS.contains("ArrowRight"))
  }

  @Test
  func createPrototypeDoesNotWriteSlideRuntime() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Prototype",
      kind: .prototype,
      designSystem: .apple,
      fidelity: .highFidelity
    ))

    let projectURL = URL(fileURLWithPath: project.workingDirectory)

    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("deck-stage.js").path) == false)
  }

  @Test
  func deleteProjectRemovesProjectFolder() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "Delete Me",
      kind: .prototype,
      designSystem: .airbnb,
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

    #expect(project.designSystem == .preset(.material))
    #expect(project.designSystems == [.preset(.material)])
    #expect(project.designSystem.displayName == "Material Design")
  }

  @Test
  func projectDecodingSupportsDesignSystemPrecedenceList() throws {
    let json = """
    {
      "createdAt": "2026-01-01T00:00:00Z",
      "designSystems": [
        {
          "detail": "AgentHub product UI",
          "displayName": "AgentHub Design System",
          "kind": "custom",
          "notes": "Dense shell",
          "referenceID": "agenthub",
          "sourceLinks": ["https://github.com/example/agenthub"],
          "workingDirectory": "/tmp/agenthub-design-system"
        },
        "airbnb"
      ],
      "fidelity": "highFidelity",
      "id": "00000000-0000-0000-0000-000000000001",
      "kind": "prototype",
      "name": "Precedence",
      "updatedAt": "2026-01-01T00:00:00Z",
      "workingDirectory": "/tmp/precedence"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let project = try decoder.decode(EaselDesignProject.self, from: Data(json.utf8))

    #expect(project.designSystems.map(\.displayName) == [
      "AgentHub Design System",
      "Airbnb Design System",
    ])
    #expect(project.designSystemDisplaySummary == "AgentHub Design System -> Airbnb Design System")
  }

  @Test
  func createProjectCopiesCustomDesignSystemIntoResources() async throws {
    let rootDirectory = temporaryRoot()
    let designSystemRoot = temporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: designSystemRoot)
    }

    let designSystemURL = try makeFakeDesignSystem(named: "OpenAI", in: designSystemRoot)
    let choice = EaselDesignSystemChoice(
      kind: .custom,
      referenceID: UUID().uuidString,
      displayName: "OpenAI",
      detail: "OpenAI brand",
      workingDirectory: designSystemURL.path,
      notes: nil,
      sourceLinks: []
    )

    let manager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await manager.createProject(from: EaselProjectCreateRequest(
      name: "OpenAI Landing",
      kind: .prototype,
      designSystem: choice,
      fidelity: .highFidelity
    ))

    let base = URL(fileURLWithPath: project.workingDirectory)
      .appendingPathComponent("resources/design-systems/openai", isDirectory: true)
    #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("catalog.json").path))
    #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("assets/logo.png").path))

    let copiedCatalog = try String(contentsOf: base.appendingPathComponent("catalog.json"), encoding: .utf8)
    #expect(copiedCatalog.contains("\"name\":\"OpenAI\""))
  }

  private func makeFakeDesignSystem(named name: String, in rootURL: URL) throws -> URL {
    let designSystemURL = rootURL.appendingPathComponent(name.lowercased(), isDirectory: true)
    let easelDir = designSystemURL.appendingPathComponent(".easel", isDirectory: true)
    let assetsDir = designSystemURL.appendingPathComponent("resources/assets", isDirectory: true)
    try FileManager.default.createDirectory(at: easelDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    try Data("{\"schemaVersion\":3,\"name\":\"\(name)\",\"summary\":\"x\"}".utf8)
      .write(to: easelDir.appendingPathComponent("catalog.json"))
    try Data("<!doctype html>".utf8)
      .write(to: designSystemURL.appendingPathComponent("index.html"))
    try Data([0, 1, 2]).write(to: assetsDir.appendingPathComponent("logo.png"))
    return designSystemURL
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselProjectManagerTests-\(UUID().uuidString)", isDirectory: true)
  }
}
