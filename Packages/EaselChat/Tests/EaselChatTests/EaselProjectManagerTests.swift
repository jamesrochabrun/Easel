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
  func launchPromptIncludesProjectContextAndSeedPrompt() {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Checkout Prototype",
      kind: .prototype,
      designSystem: .material,
      fidelity: .wireframe,
      workingDirectory: "/tmp/checkout-prototype",
      createdAt: Date(),
      updatedAt: Date()
    )

    let prompt = project.launchPrompt(seedPrompt: "Make checkout faster")

    #expect(prompt.contains("Checkout Prototype"))
    #expect(prompt.contains("/tmp/checkout-prototype"))
    #expect(prompt.contains("Wireframe"))
    #expect(prompt.contains("Material Design"))
    #expect(prompt.contains("User brief: Make checkout faster"))
    #expect(prompt.contains("resources/"))
    #expect(prompt.contains("npm run dev"))
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
    #expect(project.designSystem.displayName == "Material Design")
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselProjectManagerTests-\(UUID().uuidString)", isDirectory: true)
  }
}
