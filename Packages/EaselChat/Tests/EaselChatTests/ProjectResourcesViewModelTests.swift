//
//  ProjectResourcesViewModelTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselChat

@MainActor
struct ProjectResourcesViewModelTests {

  @Test
  func refreshPrefersCurrentProjectAndLoadsResources() async {
    let firstProject = makeProject(name: "First", path: "/tmp/first")
    let secondProject = makeProject(name: "Second", path: "/tmp/second")
    let resource = makeResource(projectPath: secondProject.workingDirectory, fileName: "hero.png")
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [firstProject, secondProject]),
      resourceManager: StubProjectResourceManager(resourcesByProject: [
        secondProject.workingDirectory: [resource]
      ])
    )

    await viewModel.refresh(currentProjectPath: secondProject.workingDirectory)

    #expect(viewModel.selectedProjectPath == secondProject.workingDirectory)
    #expect(viewModel.resources == [resource])
  }

  @Test
  func importResourcesLoadsImportedAssets() async {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let importedResource = makeResource(projectPath: project.workingDirectory, fileName: "brief.pdf")
    let resourceManager = StubProjectResourceManager(
      resourcesByProject: [:],
      importedResources: [importedResource]
    )
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: resourceManager
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.importResources(from: [URL(fileURLWithPath: "/tmp/brief.pdf")])

    #expect(viewModel.selectedProjectPath == project.workingDirectory)
    #expect(viewModel.resources == [importedResource])
  }

  private func makeProject(name: String, path: String) -> EaselDesignProject {
    EaselDesignProject(
      id: UUID(),
      name: name,
      kind: .prototype,
      designSystem: .airbnb,
      fidelity: .highFidelity,
      workingDirectory: path,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func makeResource(projectPath: String, fileName: String) -> ProjectResource {
    ProjectResource(
      projectPath: projectPath,
      fileName: fileName,
      relativePath: "resources/\(fileName)",
      fileURL: URL(fileURLWithPath: "\(projectPath)/resources/\(fileName)"),
      kind: fileName.hasSuffix(".pdf") ? .pdf : .image,
      byteCount: 128,
      modifiedAt: Date()
    )
  }
}

private actor StubProjectManager: EaselProjectManaging {
  private let projects: [EaselDesignProject]

  init(projects: [EaselDesignProject]) {
    self.projects = projects
  }

  func loadProjects() async throws -> [EaselDesignProject] {
    projects
  }

  func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject {
    projects[0]
  }

  func deleteProject(_ project: EaselDesignProject) async throws {}
}

private actor StubProjectResourceManager: ProjectResourceManaging {
  private var resourcesByProject: [String: [ProjectResource]]
  private let importedResources: [ProjectResource]

  init(
    resourcesByProject: [String: [ProjectResource]],
    importedResources: [ProjectResource] = []
  ) {
    self.resourcesByProject = resourcesByProject
    self.importedResources = importedResources
  }

  func loadResources(forProjectAt projectPath: String) async throws -> [ProjectResource] {
    resourcesByProject[projectPath] ?? []
  }

  func importResources(from sourceURLs: [URL], intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    resourcesByProject[projectPath] = importedResources
    return importedResources
  }
}
