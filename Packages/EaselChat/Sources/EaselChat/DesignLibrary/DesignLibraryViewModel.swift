//
//  DesignLibraryViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation

@Observable @MainActor
public final class DesignLibraryViewModel {
  public private(set) var items: [DesignLibraryItem] = []
  public private(set) var isLoading = false
  public private(set) var errorMessage: String?

  private let sessionStorage: SessionStorageProtocol
  private let projectManager: any EaselProjectManaging
  private let designSystemManager: any EaselDesignSystemManaging
  private let fileManager: FileManager

  public init(
    sessionStorage: SessionStorageProtocol,
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager(),
    fileManager: FileManager = .default
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    self.designSystemManager = designSystemManager
    self.fileManager = fileManager
  }

  public func refresh() async {
    isLoading = true
    defer { isLoading = false }

    var failures: [String] = []
    var projects: [EaselDesignProject] = []
    var designSystems: [EaselDesignSystemProfile] = []
    var sessions: [StoredSession] = []

    do {
      projects = try await projectManager.loadProjects()
    } catch {
      failures.append("Projects: \(error.localizedDescription)")
    }

    do {
      designSystems = try await designSystemManager.loadDesignSystems()
    } catch {
      failures.append("Design systems: \(error.localizedDescription)")
    }

    do {
      sessions = try await sessionStorage.getAllSessions()
    } catch {
      failures.append("Sessions: \(error.localizedDescription)")
    }

    let sessionsByDirectory = Dictionary(grouping: sessions) { session in
      session.workingDirectory ?? ""
    }

    let projectItems = projects.map { project in
      DesignLibraryItem(
        id: "project:\(project.id.uuidString)",
        title: project.name,
        kind: DesignLibraryItemKind(projectKind: project.kind),
        workingDirectory: project.workingDirectory,
        updatedAt: project.updatedAt,
        latestSession: latestSession(in: sessionsByDirectory[project.workingDirectory] ?? []),
        previewFile: previewFile(for: project.workingDirectory),
        project: project,
        designSystem: nil
      )
    }

    let designSystemItems = designSystems.map { designSystem in
      DesignLibraryItem(
        id: "design-system:\(designSystem.id.uuidString)",
        title: designSystem.name,
        kind: .designSystem,
        workingDirectory: designSystem.workingDirectory,
        updatedAt: designSystem.updatedAt,
        latestSession: latestSession(in: sessionsByDirectory[designSystem.workingDirectory] ?? []),
        previewFile: previewFile(for: designSystem.workingDirectory),
        project: nil,
        designSystem: designSystem
      )
    }

    items = (projectItems + designSystemItems).sorted(by: sortLibraryItems)
    errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
  }

  private func latestSession(in sessions: [StoredSession]) -> StoredSession? {
    sessions.max { lhs, rhs in
      lhs.lastAccessedAt < rhs.lastAccessedAt
    }
  }

  private func previewFile(for workingDirectory: String) -> DesignLibraryPreviewFile? {
    let directoryURL = URL(fileURLWithPath: workingDirectory)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let indexURL = directoryURL.appendingPathComponent("index.html")

    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue,
          fileManager.fileExists(atPath: indexURL.path) else {
      return nil
    }

    let values = try? indexURL.resourceValues(forKeys: [
      .contentModificationDateKey,
      .fileSizeKey,
    ])

    return DesignLibraryPreviewFile(
      url: indexURL,
      readAccessURL: directoryURL,
      modificationDate: values?.contentModificationDate,
      byteCount: values?.fileSize
    )
  }

  private func sortLibraryItems(_ lhs: DesignLibraryItem, _ rhs: DesignLibraryItem) -> Bool {
    if lhs.activityDate == rhs.activityDate {
      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    return lhs.activityDate > rhs.activityDate
  }
}
