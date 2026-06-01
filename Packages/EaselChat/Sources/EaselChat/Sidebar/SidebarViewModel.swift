//
//  SidebarViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

@Observable @MainActor
public final class SidebarViewModel {

  // MARK: - Public State

  private(set) var projectGroups: [ProjectGroup] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true
  var selectedProjectKind: EaselProjectKind = .prototype
  var projectName: String = ""
  var selectedDesignSystem: EaselDesignSystemPreset = .airbnb
  var selectedFidelity: EaselProjectFidelity = .highFidelity
  var isCreatingProject = false
  var creationError: String?
  var projectDeletionError: String?

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onNewChatRequested: ((String?) -> Void)?
  public var onProjectLaunchRequested: ((EaselProjectLaunch) -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private let projectManager: any EaselProjectManaging

  private static let legacyProjectDirectoriesKey = "easel.addedProjectDirectories"

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol,
    projectManager: any EaselProjectManaging = LocalEaselProjectManager()
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    UserDefaults.standard.removeObject(forKey: Self.legacyProjectDirectoriesKey)
  }

  // MARK: - Public Methods

  public func loadSessions() async {
    do {
      let sessions = try await sessionStorage.getAllSessions()
      let previousExpansion = Dictionary(uniqueKeysWithValues: projectGroups.map { ($0.id, $0.isExpanded) })
      let projects = (try? await projectManager.loadProjects()) ?? []
      projectGroups = ProjectGroup.groups(
        projects: projects,
        sessions: sessions,
        previousExpansion: previousExpansion
      )
    } catch {
      projectGroups = []
    }
  }

  func toggleProject(_ projectId: String) {
    guard let index = projectGroups.firstIndex(where: { $0.id == projectId }) else { return }
    projectGroups[index].isExpanded.toggle()
  }

  public func toggleSidebar() {
    isSidebarVisible.toggle()
  }

  public func createPrototypeProject(fromPrompt prompt: String) async {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    selectedProjectKind = .prototype
    selectedFidelity = .highFidelity
    projectName = Self.suggestedProjectName(from: trimmed)
    await createProjectAndStartSession(seedPrompt: trimmed)
  }

  func selectSession(_ session: StoredSession) {
    selectedSessionId = session.id
    onSessionSelected?(session)
  }

  func requestNewChat(workingDirectory: String?) {
    selectedSessionId = nil
    onNewChatRequested?(workingDirectory)
  }

  func deleteSession(_ session: StoredSession) {
    onDeleteSession?(session)
  }

  func deleteProject(_ projectGroup: ProjectGroup) async {
    guard let project = projectGroup.project else { return }

    projectDeletionError = nil

    do {
      try await projectManager.deleteProject(project)

      for session in projectGroup.sessions {
        try? await sessionStorage.deleteSession(id: session.id)
        onDeleteSession?(session)
      }

      if projectGroup.sessions.contains(where: { $0.id == selectedSessionId }) {
        selectedSessionId = nil
      }

      await loadSessions()
    } catch {
      projectDeletionError = error.localizedDescription
    }
  }

  func createProjectAndStartSession(seedPrompt: String? = nil) async {
    let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }

    isCreatingProject = true
    creationError = nil
    projectDeletionError = nil
    defer { isCreatingProject = false }

    let request = EaselProjectCreateRequest(
      name: name,
      kind: selectedProjectKind,
      designSystem: selectedDesignSystem,
      fidelity: selectedFidelity
    )

    do {
      let project = try await projectManager.createProject(from: request)
      projectName = ""
      selectedSessionId = nil
      await loadSessions()
      onProjectLaunchRequested?(EaselProjectLaunch(
        project: project,
        prompt: ""
      ))
    } catch {
      creationError = error.localizedDescription
    }
  }

  // MARK: - Private

  private static func suggestedProjectName(from prompt: String) -> String {
    let collapsed = prompt
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
    let limit = 48
    if collapsed.count <= limit {
      return collapsed
    }

    return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
