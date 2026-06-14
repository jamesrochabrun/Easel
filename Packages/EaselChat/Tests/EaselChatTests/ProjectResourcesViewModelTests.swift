//
//  ProjectResourcesViewModelTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
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
  func deleteRemovesResourceAndReloads() async {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let keep = makeResource(projectPath: project.workingDirectory, fileName: "keep.png")
    let remove = makeResource(projectPath: project.workingDirectory, fileName: "remove.png")
    let resourceManager = StubProjectResourceManager(
      resourcesByProject: [project.workingDirectory: [keep, remove]]
    )
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: resourceManager
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.deleteItem(.resource(remove))

    #expect(viewModel.resources == [keep])
    #expect(await resourceManager.deletedItemIDs == [ProjectResourcePanelItem.resource(remove).id])
    #expect(viewModel.errorMessage == nil)
  }

  @Test
  func deleteRejectsProtectedProjectFile() async {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let index = makeProjectStructureItem(projectPath: project.workingDirectory, fileName: "index.html")
    let resourceManager = StubProjectResourceManager(
      resourcesByProject: [:],
      projectStructureByProject: [
        project.workingDirectory: [ProjectStructureSection(role: .pages, items: [index])]
      ]
    )
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: resourceManager
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.deleteItem(.projectFile(index))

    #expect(await resourceManager.deletedItemIDs.isEmpty)
    #expect(viewModel.errorMessage != nil)
  }

  @Test
  func protectedFilesAreNotDeletable() {
    let path = "/tmp/project"
    let index = makeProjectStructureItem(projectPath: path, fileName: "index.html")
    let readme = makeProjectStructureItem(projectPath: path, fileName: "README.md")
    let packageJSON = makeProjectStructureItem(projectPath: path, fileName: "package.json")
    let styles = makeProjectStructureItem(projectPath: path, fileName: "styles.css")
    let resource = makeResource(projectPath: path, fileName: "hero.png")

    #expect(ProjectResourcePanelItem.projectFile(index).isDeletable == false)
    #expect(ProjectResourcePanelItem.projectFile(readme).isDeletable == false)
    #expect(ProjectResourcePanelItem.projectFile(packageJSON).isDeletable == false)
    #expect(ProjectResourcePanelItem.projectFile(styles).isDeletable == true)
    #expect(ProjectResourcePanelItem.resource(resource).isDeletable == true)
  }

  @Test
  func refreshHonorsDesignSystemWorkspaceInsteadOfFallingBackToProject() async {
    let project = makeProject(name: "Proto", path: "/tmp/proto")
    let designSystemPath = "/tmp/design-systems/plusui"
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Plus UI",
      blurb: "Plus UI kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: designSystemPath,
      createdAt: Date(),
      updatedAt: Date()
    )
    let resource = makeResource(projectPath: designSystemPath, fileName: "tokens.json")
    let page = makeProjectStructureItem(projectPath: designSystemPath, fileName: "index.html")
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: StubProjectResourceManager(
        resourcesByProject: [designSystemPath: [resource]],
        projectStructureByProject: [designSystemPath: [ProjectStructureSection(role: .pages, items: [page])]]
      ),
      designSystemManager: StubDesignSystemManager(designSystems: [designSystem])
    )

    await viewModel.refresh(currentProjectPath: designSystemPath)

    #expect(viewModel.selectedProjectPath == designSystemPath)
    #expect(viewModel.selectedProject == nil)
    #expect(viewModel.selectedDesignSystem?.id == designSystem.id)
    #expect(viewModel.resources == [resource])
    #expect(viewModel.hasProjectFiles)
  }

  @Test
  func clearSelectionReturnsToResourceLibrary() async {
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
    viewModel.clearSelection()

    #expect(viewModel.selectedItem == nil)
    #expect(viewModel.selectedPreview == nil)
    #expect(viewModel.isPreviewLoading == false)
    #expect(viewModel.isSavingPreview == false)
  }

  @Test
  func saveTextPreviewUpdatesSelectedPreview() async {
    let project = makeProject(name: "Project", path: "/tmp/project")
    let resource = makeResource(projectPath: project.workingDirectory, fileName: "notes.txt")
    let item = ProjectResourcePanelItem.resource(resource)
    let viewModel = ProjectResourcesViewModel(
      projectManager: StubProjectManager(projects: [project]),
      resourceManager: StubProjectResourceManager(
        resourcesByProject: [project.workingDirectory: [resource]],
        previewsByItemID: [
          item.id: ProjectResourcePreview(itemID: item.id, content: .text("Initial"))
        ]
      )
    )

    await viewModel.refresh(currentProjectPath: project.workingDirectory)
    await viewModel.select(item)
    await viewModel.saveTextPreview("Updated", for: item)

    #expect(viewModel.selectedPreview == ProjectResourcePreview(itemID: item.id, content: .text("Updated")))
    #expect(viewModel.isSavingPreview == false)
    #expect(viewModel.errorMessage == nil)
  }

  private func makeProject(name: String, path: String) -> EaselDesignProject {
    EaselDesignProject(
      id: UUID(),
      name: name,
      kind: .prototype,
      designSystem: .none,
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
    ProjectResourcePreview(itemID: item.id, content: .text(text))
  }

  func importResources(from sourceURLs: [URL], intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    resourcesByProject[projectPath] = importedResources
    return importedResources
  }

  func importReferenceCodebase(from sourceURL: URL, intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    importedResources
  }

  private(set) var deletedItemIDs: [String] = []

  func deleteItem(_ item: ProjectResourcePanelItem) async throws {
    deletedItemIDs.append(item.id)
    for (project, resources) in resourcesByProject {
      resourcesByProject[project] = resources.filter {
        ProjectResourcePanelItem.resource($0).id != item.id
      }
    }
  }
}

private actor StubDesignSystemManager: EaselDesignSystemManaging {
  private let designSystems: [EaselDesignSystemProfile]

  init(designSystems: [EaselDesignSystemProfile] = []) {
    self.designSystems = designSystems
  }

  func loadDesignSystems() async throws -> [EaselDesignSystemProfile] {
    designSystems
  }

  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    throw NSError(domain: "StubDesignSystemManager", code: 1)
  }

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {}

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    nil
  }
}
