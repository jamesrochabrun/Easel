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
      designSystem: .apple,
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
      kind: .slideDeck,
      designSystem: .material,
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

  private func temporaryRoot(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
  }
}
