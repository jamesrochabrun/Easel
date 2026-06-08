//
//  ProjectResourcesViewModel.swift
//  EaselChat
//

import EaselDesignSystems
import Foundation

@Observable @MainActor
public final class ProjectResourcesViewModel {
  public private(set) var projects: [EaselDesignProject] = []
  public private(set) var designSystems: [EaselDesignSystemProfile] = []
  public private(set) var resources: [ProjectResource] = []
  public private(set) var projectStructureSections: [ProjectStructureSection] = []
  public private(set) var selectedItem: ProjectResourcePanelItem?
  public private(set) var selectedPreview: ProjectResourcePreview?
  public private(set) var isLoading = false
  public private(set) var isImporting = false
  public private(set) var isPreviewLoading = false
  public private(set) var isSavingPreview = false
  public private(set) var errorMessage: String?
  public var selectedProjectPath: String?

  private let projectManager: any EaselProjectManaging
  private let resourceManager: any ProjectResourceManaging
  private let designSystemManager: any EaselDesignSystemManaging

  public init(
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    resourceManager: any ProjectResourceManaging = LocalProjectResourceManager(),
    designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()
  ) {
    self.projectManager = projectManager
    self.resourceManager = resourceManager
    self.designSystemManager = designSystemManager
  }

  public var selectedProject: EaselDesignProject? {
    guard let selectedProjectPath else { return nil }
    return projects.first { $0.workingDirectory == selectedProjectPath }
  }

  public var selectedDesignSystem: EaselDesignSystemProfile? {
    guard let selectedProjectPath else { return nil }
    return designSystems.first { $0.workingDirectory == selectedProjectPath }
  }

  public var hasProjectFiles: Bool {
    !resources.isEmpty || projectStructureSections.contains { !$0.items.isEmpty }
  }

  public func refresh(currentProjectPath: String? = nil) async {
    isLoading = true
    defer { isLoading = false }

    do {
      let loadedProjects = try await projectManager.loadProjects()
      projects = loadedProjects
      designSystems = (try? await designSystemManager.loadDesignSystems()) ?? []
      selectedProjectPath = Self.preferredSelection(
        currentProjectPath: currentProjectPath,
        existingSelection: selectedProjectPath,
        projects: loadedProjects
      )
      try await loadResourcesForSelectedProject()
      errorMessage = nil
    } catch {
      projects = []
      designSystems = []
      resources = []
      projectStructureSections = []
      selectedItem = nil
      selectedPreview = nil
      selectedProjectPath = nil
      errorMessage = error.localizedDescription
    }
  }

  public func loadResourcesForSelection() async {
    do {
      try await loadResourcesForSelectedProject()
      errorMessage = nil
    } catch {
      resources = []
      projectStructureSections = []
      selectedItem = nil
      selectedPreview = nil
      errorMessage = error.localizedDescription
    }
  }

  public func importResources(from sourceURLs: [URL]) async {
    guard let selectedProjectPath else { return }

    isImporting = true
    defer { isImporting = false }

    do {
      resources = try await resourceManager.importResources(
        from: sourceURLs,
        intoProjectAt: selectedProjectPath
      )
      projectStructureSections = try await resourceManager.loadProjectStructure(forProjectAt: selectedProjectPath)
      reconcileSelection()
      let loadedProjects = try await projectManager.loadProjects()
      projects = loadedProjects
      self.selectedProjectPath = loadedProjects.first { $0.workingDirectory == selectedProjectPath }?.workingDirectory
        ?? selectedProjectPath
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func reportImportFailure(_ error: Error) {
    errorMessage = error.localizedDescription
  }

  public func select(_ item: ProjectResourcePanelItem) async {
    selectedItem = item
    selectedPreview = nil
    isPreviewLoading = true

    do {
      let preview = try await resourceManager.loadPreview(for: item)
      guard selectedItem?.id == item.id else { return }

      selectedPreview = preview
      isPreviewLoading = false
    } catch {
      guard selectedItem?.id == item.id else { return }

      selectedPreview = ProjectResourcePreview(
        itemID: item.id,
        content: .unavailable(error.localizedDescription)
      )
      isPreviewLoading = false
    }
  }

  public func clearSelection() {
    selectedItem = nil
    selectedPreview = nil
    isPreviewLoading = false
    isSavingPreview = false
  }

  public func saveTextPreview(_ text: String, for item: ProjectResourcePanelItem) async {
    guard selectedItem?.id == item.id else { return }

    isSavingPreview = true
    defer { isSavingPreview = false }

    do {
      let preview = try await resourceManager.saveText(text, for: item)
      guard selectedItem?.id == item.id else { return }

      selectedPreview = preview
      errorMessage = nil
    } catch {
      guard selectedItem?.id == item.id else { return }

      errorMessage = error.localizedDescription
    }
  }

  private func loadResourcesForSelectedProject() async throws {
    guard let selectedProjectPath else {
      resources = []
      projectStructureSections = []
      selectedItem = nil
      selectedPreview = nil
      return
    }

    async let loadedResources = resourceManager.loadResources(forProjectAt: selectedProjectPath)
    async let loadedProjectStructure = resourceManager.loadProjectStructure(forProjectAt: selectedProjectPath)
    let (resources, projectStructureSections) = try await (loadedResources, loadedProjectStructure)

    self.resources = resources
    self.projectStructureSections = projectStructureSections
    reconcileSelection()
  }

  private func reconcileSelection() {
    guard let selectedItem else { return }

    let resourceItems = resources.map(ProjectResourcePanelItem.resource)
    let projectFileItems = projectStructureSections.flatMap(\.items).map(ProjectResourcePanelItem.projectFile)
    let itemIDs = Set((resourceItems + projectFileItems).map(\.id))
    if !itemIDs.contains(selectedItem.id) {
      self.selectedItem = nil
      selectedPreview = nil
      isPreviewLoading = false
    }
  }

  private static func preferredSelection(
    currentProjectPath: String?,
    existingSelection: String?,
    projects: [EaselDesignProject]
  ) -> String? {
    // Honor the active working directory directly — it may be a managed project
    // or a design system, both of which hold resources loadable by path. Only
    // fall back to the first project when no workspace is active.
    if let currentProjectPath, !currentProjectPath.isEmpty {
      return currentProjectPath
    }

    if let existingSelection, !existingSelection.isEmpty {
      return existingSelection
    }

    return projects.first?.workingDirectory
  }
}
