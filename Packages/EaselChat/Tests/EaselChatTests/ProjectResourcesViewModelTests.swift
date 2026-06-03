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
    let page = makeProjectStructureItem(projectPath: secondProject.workingDirectory, fileName: "index.html")
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [firstProject, secondProject]),
      resourceManager: StubProjectResourceManager(resourcesByProject: [
        secondProject.workingDirectory: [resource]
      ], projectStructureByProject: [
        secondProject.workingDirectory: [ProjectStructureSection(role: .pages, items: [page])]
      ])
    )

    await viewModel.refresh(currentProjectPath: secondProject.workingDirectory)

    #expect(viewModel.selectedProjectPath == secondProject.workingDirectory)
    #expect(viewModel.resources == [resource])
    #expect(viewModel.projectStructureSections == [ProjectStructureSection(role: .pages, items: [page])])
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

  @Test
  func selectResourceLoadsPreview() async {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let resource = makeResource(projectPath: project.workingDirectory, fileName: "notes.txt")
    let item = ProjectResourcePanelItem.resource(resource)
    let preview = ProjectResourcePreview(itemID: item.id, content: .text("Preview body"))
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: StubProjectResourceManager(
        resourcesByProject: [project.workingDirectory: [resource]],
        previewsByItemID: [item.id: preview]
      )
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.select(item)

    #expect(viewModel.selectedItem == item)
    #expect(viewModel.selectedPreview == preview)
    #expect(viewModel.isPreviewLoading == false)
  }

  @Test
  func saveTextPreviewPersistsTextAndUpdatesSelectedPreview() async throws {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let page = makeProjectStructureItem(projectPath: project.workingDirectory, fileName: "index.html")
    let item = ProjectResourcePanelItem.projectFile(page)
    let resourceManager = StubProjectResourceManager(
      resourcesByProject: [:],
      projectStructureByProject: [
        project.workingDirectory: [ProjectStructureSection(role: .pages, items: [page])]
      ],
      previewsByItemID: [
        item.id: ProjectResourcePreview(itemID: item.id, content: .text("<h1>Draft</h1>"))
      ]
    )
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: resourceManager
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.select(item)
    try await viewModel.saveTextPreview("<h1>Saved</h1>", for: item)

    let savedText = await resourceManager.savedText(for: item.id)
    #expect(savedText == "<h1>Saved</h1>")
    #expect(viewModel.selectedPreview?.content == .text("<h1>Saved</h1>"))
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

  private func makeProjectStructureItem(projectPath: String, fileName: String) -> ProjectStructureItem {
    ProjectStructureItem(
      projectPath: projectPath,
      fileName: fileName,
      relativePath: fileName,
      fileURL: URL(fileURLWithPath: "\(projectPath)/\(fileName)"),
      kind: .document,
      role: fileName.hasSuffix(".html") ? .pages : .documents,
      byteCount: 256,
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
  private var projectStructureByProject: [String: [ProjectStructureSection]]
  private let importedResources: [ProjectResource]
  private let previewsByItemID: [String: ProjectResourcePreview]
  private var savedTextsByItemID: [String: String] = [:]

  init(
    resourcesByProject: [String: [ProjectResource]],
    projectStructureByProject: [String: [ProjectStructureSection]] = [:],
    importedResources: [ProjectResource] = [],
    previewsByItemID: [String: ProjectResourcePreview] = [:]
  ) {
    self.resourcesByProject = resourcesByProject
    self.projectStructureByProject = projectStructureByProject
    self.importedResources = importedResources
    self.previewsByItemID = previewsByItemID
  }

  func loadResources(forProjectAt projectPath: String) async throws -> [ProjectResource] {
    resourcesByProject[projectPath] ?? []
  }

  func loadProjectStructure(forProjectAt projectPath: String) async throws -> [ProjectStructureSection] {
    projectStructureByProject[projectPath] ?? []
  }

  func loadPreview(for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview {
    previewsByItemID[item.id] ?? ProjectResourcePreview(itemID: item.id, content: .visual)
  }

  func saveText(_ text: String, for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview {
    savedTextsByItemID[item.id] = text
    return ProjectResourcePreview(itemID: item.id, content: .text(text))
  }

  func importResources(from sourceURLs: [URL], intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    resourcesByProject[projectPath] = importedResources
    return importedResources
  }

  func savedText(for itemID: String) -> String? {
    savedTextsByItemID[itemID]
  }
}
