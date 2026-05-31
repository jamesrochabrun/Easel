//
//  ProjectResourcesViewModel.swift
//  EaselChat
//

import Foundation

@Observable @MainActor
public final class ProjectResourcesViewModel {
  public private(set) var projects: [EaselDesignProject] = []
  public private(set) var resources: [ProjectResource] = []
  public private(set) var isLoading = false
  public private(set) var isImporting = false
  public private(set) var errorMessage: String?
  public var selectedProjectPath: String?

  private let projectManager: any EaselProjectManaging
  private let resourceManager: any ProjectResourceManaging

  public init(
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    resourceManager: any ProjectResourceManaging = LocalProjectResourceManager()
  ) {
    self.projectManager = projectManager
    self.resourceManager = resourceManager
  }

  public var selectedProject: EaselDesignProject? {
    guard let selectedProjectPath else { return nil }
    return projects.first { $0.workingDirectory == selectedProjectPath }
  }

  public func refresh(currentProjectPath: String? = nil) async {
    isLoading = true
    defer { isLoading = false }

    do {
      let loadedProjects = try await projectManager.loadProjects()
      projects = loadedProjects
      selectedProjectPath = Self.preferredSelection(
        currentProjectPath: currentProjectPath,
        existingSelection: selectedProjectPath,
        projects: loadedProjects
      )
      try await loadResourcesForSelectedProject()
      errorMessage = nil
    } catch {
      projects = []
      resources = []
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

  private func loadResourcesForSelectedProject() async throws {
    guard let selectedProjectPath else {
      resources = []
      return
    }

    resources = try await resourceManager.loadResources(forProjectAt: selectedProjectPath)
  }

  private static func preferredSelection(
    currentProjectPath: String?,
    existingSelection: String?,
    projects: [EaselDesignProject]
  ) -> String? {
    if let currentProjectPath, projects.contains(where: { $0.workingDirectory == currentProjectPath }) {
      return currentProjectPath
    }

    if let existingSelection, projects.contains(where: { $0.workingDirectory == existingSelection }) {
      return existingSelection
    }

    return projects.first?.workingDirectory
  }
}
