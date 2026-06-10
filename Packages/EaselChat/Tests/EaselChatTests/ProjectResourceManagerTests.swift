//
//  ProjectResourceManagerTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselChat

struct ProjectResourceManagerTests {

  @Test
  func importResourcesCopiesFilesIntoProjectResourcesFolder() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourceManagerTests")
    let sourceDirectory = temporaryRoot(named: "ProjectResourceSourceTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: sourceDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Catalog Prototype",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    let imageURL = sourceDirectory.appendingPathComponent("hero.png")
    let pdfURL = sourceDirectory.appendingPathComponent("brief.pdf")
    try Data([0, 1, 2, 3]).write(to: imageURL)
    try Data([4, 5, 6]).write(to: pdfURL)

    let manager = LocalProjectResourceManager()
    let resources = try await manager.importResources(
      from: [imageURL, pdfURL],
      intoProjectAt: project.workingDirectory
    )

    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/hero.png").path))
    #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("resources/brief.pdf").path))
    #expect(resources.first { $0.fileName == "hero.png" }?.kind == .image)
    #expect(resources.first { $0.fileName == "brief.pdf" }?.kind == .pdf)

    let loadedResources = try await manager.loadResources(forProjectAt: project.workingDirectory)
    #expect(Set(loadedResources.map(\.fileName)) == Set(["hero.png", "brief.pdf"]))
  }

  @Test
  func importResourcesCreatesUniqueNamesForDuplicates() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourceDuplicateTests")
    let sourceDirectory = temporaryRoot(named: "ProjectResourceDuplicateSourceTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: sourceDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Duplicate Assets",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe
    ))

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    let sourceURL = sourceDirectory.appendingPathComponent("logo.png")
    try Data([0, 1, 2]).write(to: sourceURL)

    let manager = LocalProjectResourceManager()
    _ = try await manager.importResources(from: [sourceURL], intoProjectAt: project.workingDirectory)
    let resources = try await manager.importResources(from: [sourceURL], intoProjectAt: project.workingDirectory)

    #expect(Set(resources.map(\.fileName)) == Set(["logo.png", "logo 2.png"]))
  }

  @Test
  func importResourcesRejectsDirectoryOnlySelections() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourceDirectoryTests")
    let sourceDirectory = temporaryRoot(named: "ProjectResourceDirectorySourceTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
      try? FileManager.default.removeItem(at: sourceDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Directory Selection",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe
    ))
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

    let manager = LocalProjectResourceManager()

    do {
      _ = try await manager.importResources(from: [sourceDirectory], intoProjectAt: project.workingDirectory)
      Issue.record("Expected directory-only import to fail")
    } catch let error as ProjectResourceError {
      #expect(error == .noImportableFiles)
    }
  }

  @Test
  func loadProjectStructureGroupsGeneratedFilesAndSkipsManagedResources() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourceStructureTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Project Structure",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))
    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    try write("html", to: projectURL.appendingPathComponent("index.html"))
    try write("console.log('stage')", to: projectURL.appendingPathComponent("deck-stage.js"))
    try FileManager.default.createDirectory(
      at: projectURL.appendingPathComponent("styles", isDirectory: true),
      withIntermediateDirectories: true
    )
    try write("body {}", to: projectURL.appendingPathComponent("styles/site.css"))
    try write("managed asset", to: projectURL.appendingPathComponent("resources/hero.png"))

    let manager = LocalProjectResourceManager()
    let sections = try await manager.loadProjectStructure(forProjectAt: project.workingDirectory)
    let pages = sections.first { $0.role == .pages }?.items.map(\.relativePath) ?? []
    let scripts = sections.first { $0.role == .scripts }?.items.map(\.relativePath) ?? []
    let styles = sections.first { $0.role == .styles }?.items.map(\.relativePath) ?? []
    let allPaths = sections.flatMap(\.items).map(\.relativePath)

    #expect(pages == ["index.html"])
    #expect(scripts == ["deck-stage.js"])
    #expect(styles == ["styles/site.css"])
    #expect(allPaths.contains("resources/hero.png") == false)
  }

  @Test
  func loadPreviewReturnsTextForTextFiles() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourcePreviewTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Preview Text",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe
    ))
    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    try write("const title = 'Easel'", to: projectURL.appendingPathComponent("app.js"))

    let manager = LocalProjectResourceManager()
    let sections = try await manager.loadProjectStructure(forProjectAt: project.workingDirectory)
    let script = try #require(sections.first { $0.role == .scripts }?.items.first)
    let preview = try await manager.loadPreview(for: .projectFile(script))

    #expect(preview.content == .text("const title = 'Easel'"))
  }

  @Test
  func saveTextWritesSelectedFileAndReturnsUpdatedPreview() async throws {
    let rootDirectory = temporaryRoot(named: "ProjectResourceSaveTests")
    defer {
      try? FileManager.default.removeItem(at: rootDirectory)
    }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Editable Files",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe
    ))
    let projectURL = URL(fileURLWithPath: project.workingDirectory)
    let fileURL = projectURL.appendingPathComponent("index.html")
    try write("<h1>Initial</h1>", to: fileURL)

    let manager = LocalProjectResourceManager()
    let sections = try await manager.loadProjectStructure(forProjectAt: project.workingDirectory)
    let page = try #require(sections.first { $0.role == .pages }?.items.first)
    let item = ProjectResourcePanelItem.projectFile(page)

    let preview = try await manager.saveText("<h1>Updated</h1>", for: item)
    let savedText = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(preview == ProjectResourcePreview(itemID: item.id, content: .text("<h1>Updated</h1>")))
    #expect(savedText == "<h1>Updated</h1>")
  }

  private func temporaryRoot(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
  }

  private func write(_ string: String, to url: URL) throws {
    try string.data(using: .utf8)?.write(to: url)
  }
}
