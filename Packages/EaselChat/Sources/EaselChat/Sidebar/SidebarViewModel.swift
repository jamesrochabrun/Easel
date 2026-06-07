//
//  SidebarViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation

@Observable @MainActor
public final class SidebarViewModel {

  // MARK: - Public State

  private(set) var projectGroups: [ProjectGroup] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true
  public private(set) var customDesignSystems: [EaselDesignSystemProfile] = []
  private(set) var projectHeaderScrollRequest: ProjectHeaderScrollRequest?
  var selectedProjectKind: EaselProjectKind = .prototype
  var projectName: String = ""
  var selectedDesignSystems: [EaselDesignSystemChoice] = [.preset(.none)]
  var selectedDesignSystem: EaselDesignSystemChoice {
    get {
      selectedDesignSystems.first ?? .preset(.none)
    }
    set {
      selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence([newValue])
    }
  }
  var selectedFidelity: EaselProjectFidelity = .highFidelity
  var isCreatingProject = false
  var creationError: String?
  var projectDeletionError: String?
  var designSystemError: String?

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onNewChatRequested: ((String?) -> Void)?
  public var onProjectLaunchRequested: ((EaselProjectLaunch) -> Void)?
  public var onCreateDesignSystemRequested: (() -> Void)?
  public var onBrowseDesignSystemsRequested: (() -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?
  public var onProjectDeleted: (() -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private let projectManager: any EaselProjectManaging
  private let designSystemManager: any EaselDesignSystemManaging

  private static let legacyProjectDirectoriesKey = "easel.addedProjectDirectories"

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol,
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager()
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    self.designSystemManager = designSystemManager
    UserDefaults.standard.removeObject(forKey: Self.legacyProjectDirectoriesKey)
  }

  var availableDesignSystemChoices: [EaselDesignSystemChoice] {
    [EaselDesignSystemChoice.preset(.none)]
      + EaselDesignSystemPreset.allCases
        .filter { $0 != .none }
        .map(EaselDesignSystemChoice.preset)
      + customDesignSystems.map(EaselDesignSystemChoice.custom)
  }

  var unselectedDesignSystemChoices: [EaselDesignSystemChoice] {
    availableDesignSystemChoices.filter { choice in
      !selectedDesignSystems.contains(where: { $0.id == choice.id })
    }
  }

  var selectedDesignSystemSummary: String {
    selectedDesignSystems.map(\.displayName).joined(separator: ", ")
  }

  var shouldShowCreateOnlyDesignSystemControl: Bool {
    customDesignSystems.isEmpty && selectedDesignSystems == [.preset(.none)]
  }

  var shouldShowFidelityPicker: Bool {
    selectedProjectKind == .prototype
  }

  private var projectCreationFidelity: EaselProjectFidelity {
    shouldShowFidelityPicker ? selectedFidelity : .highFidelity
  }

  // MARK: - Public Methods

  public func loadSessions() async {
    await loadDesignSystems()

    do {
      let sessions = try await sessionStorage.getAllSessions()
      let previousExpansion = Dictionary(uniqueKeysWithValues: projectGroups.map { ($0.id, $0.isExpanded) })
      let projects = (try? await projectManager.loadProjects()) ?? []
      projectGroups = ProjectGroup.groups(
        projects: projects,
        designSystems: customDesignSystems,
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

  public func requestScrollToProjectHeader(workingDirectory: String) {
    let projectGroupID = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !projectGroupID.isEmpty else { return }

    projectHeaderScrollRequest = ProjectHeaderScrollRequest(projectGroupID: projectGroupID)
  }

  func clearProjectHeaderScrollRequest(_ request: ProjectHeaderScrollRequest) {
    guard projectHeaderScrollRequest == request else { return }
    projectHeaderScrollRequest = nil
  }

  public func selectDesignSystem(_ choice: EaselDesignSystemChoice) {
    selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence([choice])
  }

  public func addDesignSystem(_ choice: EaselDesignSystemChoice) {
    selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(selectedDesignSystems + [choice])
  }

  public func removeDesignSystem(_ choice: EaselDesignSystemChoice) {
    selectedDesignSystems.removeAll { $0.id == choice.id }
    selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(selectedDesignSystems)
  }

  public func moveSelectedDesignSystems(from source: IndexSet, to destination: Int) {
    var updated = selectedDesignSystems
    let movingItems = source.sorted().map { updated[$0] }
    for index in source.sorted(by: >) {
      updated.remove(at: index)
    }

    let removedBeforeDestination = source.filter { $0 < destination }.count
    let insertionIndex = max(0, min(destination - removedBeforeDestination, updated.count))
    updated.insert(contentsOf: movingItems, at: insertionIndex)
    selectedDesignSystems = updated
    selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(selectedDesignSystems)
  }

  public func makeHighestPrecedenceDesignSystem(_ choice: EaselDesignSystemChoice) {
    var updated = selectedDesignSystems.filter { $0.id != choice.id }
    updated.insert(choice, at: 0)
    selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(updated)
  }

  public func createPrototypeProject(fromPrompt prompt: String) async {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    selectedProjectKind = .prototype
    selectedFidelity = .highFidelity
    projectName = Self.suggestedProjectName(from: trimmed)
    await createProjectAndStartSession()
  }

  func selectSession(_ session: StoredSession) {
    selectedSessionId = session.id
    onSessionSelected?(session)
  }

  func requestNewChat(workingDirectory: String?) {
    selectedSessionId = nil
    onNewChatRequested?(workingDirectory)
  }

  func requestCreateDesignSystem() {
    onCreateDesignSystemRequested?()
  }

  func requestBrowseDesignSystems() {
    onBrowseDesignSystemsRequested?()
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
      onProjectDeleted?()
    } catch {
      projectDeletionError = error.localizedDescription
    }
  }

  func createProjectAndStartSession() async {
    let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }

    isCreatingProject = true
    creationError = nil
    projectDeletionError = nil
    defer { isCreatingProject = false }

    let request = EaselProjectCreateRequest(
      name: name,
      kind: selectedProjectKind,
      designSystems: selectedDesignSystems,
      fidelity: projectCreationFidelity
    )

    do {
      let project = try await projectManager.createProject(from: request)
      projectName = ""
      selectedSessionId = nil
      await loadSessions()
      onProjectLaunchRequested?(EaselProjectLaunch(project: project))
    } catch {
      creationError = error.localizedDescription
    }
  }

  // MARK: - Private

  private func loadDesignSystems() async {
    do {
      customDesignSystems = try await designSystemManager.loadDesignSystems()
      designSystemError = nil

      let selectedBeforeValidation = selectedDesignSystems
      selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(
        selectedDesignSystems.filter { selected in
          selected.kind == .preset || availableDesignSystemChoices.contains(where: { $0.id == selected.id })
        }
      )

      if selectedBeforeValidation.contains(where: { $0.kind == .custom })
          && selectedBeforeValidation != selectedDesignSystems {
        designSystemError = "The selected design system could not be found."
      }
    } catch {
      customDesignSystems = []
      if selectedDesignSystems.contains(where: { $0.kind == .custom }) {
        selectedDesignSystems = EaselDesignSystemChoice.normalizedPrecedence(
          selectedDesignSystems.filter { $0.kind == .preset }
        )
      }
      designSystemError = error.localizedDescription
    }
  }

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

struct ProjectHeaderScrollRequest: Equatable, Sendable {
  let id = UUID()
  let projectGroupID: String
}
