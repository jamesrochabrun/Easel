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
  var projectSearchText: String = ""
  var selectedProjectKind: EaselProjectKind = .prototype
  var projectName: String = ""
  var selectedDesignSystem: EaselDesignSystemChoice = .preset(.none)
  var selectedFidelity: EaselProjectFidelity = .highFidelity
  var selectedCodebasePath: String?
  var isCreatingProject = false
  var creationError: String?
  var projectDeletionError: String?
  var designSystemError: String?
  var highFidelityContextRequest: HighFidelityProjectContextRequest?
  var wireframeContextRequest: WireframeProjectContextRequest?
  var slideDeckContextRequest: SlideDeckProjectContextRequest?

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onNewChatRequested: ((String?) -> Void)?
  /// Activate a workspace (project or design system) as the current one.
  /// Passes the working directory and the most recent session in that
  /// workspace, if any. The working directory drives project metadata lookup.
  public var onOpenWorkspace: ((String?, StoredSession?) -> Void)?
  public var onProjectLaunchRequested: ((EaselProjectLaunch) -> Void)?
  public var onCreateDesignSystemRequested: (() -> Void)?
  public var onBrowseDesignSystemsRequested: (() -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?
  public var onProjectDeleted: (() -> Void)?
  public var onDesignSystemDeleted: (() -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private let projectManager: any EaselProjectManaging
  private let designSystemManager: any EaselDesignSystemManaging
  private let resourceManager: any ProjectResourceManaging
  private var pendingNewSession: StoredSession?
  private var shouldResumeHighFidelityContextAfterDesignSystemSelection = false

  private static let legacyProjectDirectoriesKey = "easel.addedProjectDirectories"

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol,
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    designSystemManager: any EaselDesignSystemManaging = LocalEaselDesignSystemManager(),
    resourceManager: any ProjectResourceManaging = LocalProjectResourceManager()
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    self.designSystemManager = designSystemManager
    self.resourceManager = resourceManager
    UserDefaults.standard.removeObject(forKey: Self.legacyProjectDirectoriesKey)
  }

  var availableDesignSystemChoices: [EaselDesignSystemChoice] {
    [EaselDesignSystemChoice.preset(.none)]
      + customDesignSystems.map(EaselDesignSystemChoice.custom)
  }

  var shouldShowCreateOnlyDesignSystemControl: Bool {
    customDesignSystems.isEmpty && selectedDesignSystem == .preset(.none)
  }

  var shouldShowFidelityPicker: Bool {
    selectedProjectKind == .prototype
  }

  var shouldShowCodebasePicker: Bool {
    selectedProjectKind == .prototype && selectedFidelity == .highFidelity
  }

  var filteredProjectGroups: [ProjectGroup] {
    projectGroups.filter { group in
      group.matchesSearchText(projectSearchText)
    }
  }

  var isFilteringProjects: Bool {
    !projectSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var selectedCustomDesignSystem: EaselDesignSystemProfile? {
    guard selectedDesignSystem.kind == .custom,
          let designSystemID = UUID(uuidString: selectedDesignSystem.referenceID) else {
      return nil
    }

    return customDesignSystems.first { $0.id == designSystemID }
  }

  private var projectCreationFidelity: EaselProjectFidelity {
    shouldShowFidelityPicker ? selectedFidelity : .highFidelity
  }

  var shouldRequestHighFidelityContext: Bool {
    selectedProjectKind == .prototype && projectCreationFidelity == .highFidelity
  }

  var shouldRequestWireframeContext: Bool {
    selectedProjectKind == .prototype && projectCreationFidelity == .wireframe
  }

  var shouldRequestSlideDeckContext: Bool {
    selectedProjectKind == .slideDeck
  }

  private var projectCreationCodebasePath: String? {
    guard shouldShowCodebasePicker else {
      return nil
    }

    let trimmed = selectedCodebasePath?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  // MARK: - Public Methods

  public func loadSessions() async {
    await loadDesignSystems()

    do {
      let sessions = try await sessionStorage.getAllSessions()
      let sessionsForDisplay = sessionsIncludingPendingNewSession(sessions)
      let previousExpansion = Dictionary(uniqueKeysWithValues: projectGroups.map { ($0.id, $0.isExpanded) })
      let projects = (try? await projectManager.loadProjects()) ?? []
      projectGroups = ProjectGroup.groups(
        projects: projects,
        designSystems: customDesignSystems,
        sessions: sessionsForDisplay,
        previousExpansion: previousExpansion
      )
    } catch {
      projectGroups = []
    }
  }

  public func preparePendingNewSession(workingDirectory: String?) {
    let normalizedWorkingDirectory = Self.normalizedWorkingDirectory(workingDirectory)
    let now = Date()
    let session = StoredSession(
      id: UUID().uuidString.lowercased(),
      createdAt: now,
      firstUserMessage: "",
      lastAccessedAt: now,
      workingDirectory: normalizedWorkingDirectory
    )

    replacePendingNewSession(with: session)
  }

  public func completePendingNewSession(sessionId: String) {
    let normalizedSessionID = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedSessionID.isEmpty else { return }

    selectedSessionId = normalizedSessionID

    guard let pendingNewSession else { return }

    let completedPendingSession = StoredSession(
      id: normalizedSessionID,
      createdAt: pendingNewSession.createdAt,
      firstUserMessage: pendingNewSession.firstUserMessage,
      lastAccessedAt: Date(),
      messages: pendingNewSession.messages,
      workingDirectory: pendingNewSession.workingDirectory,
      branchName: pendingNewSession.branchName,
      isWorktree: pendingNewSession.isWorktree
    )

    replacePendingNewSession(with: completedPendingSession)
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

  public func containsWorkspace(workingDirectory: String?) -> Bool {
    guard let normalizedWorkingDirectory = Self.normalizedWorkingDirectory(workingDirectory) else {
      return false
    }

    return projectGroups.contains { group in
      Self.normalizedWorkingDirectory(group.workingDirectory) == normalizedWorkingDirectory
    }
  }

  @discardableResult
  public func openFirstWorkspace(excluding excludedWorkingDirectory: String?) -> Bool {
    let normalizedExcludedWorkingDirectory = Self.normalizedWorkingDirectory(excludedWorkingDirectory)
    guard let group = projectGroups.first(where: { group in
      Self.normalizedWorkingDirectory(group.workingDirectory) != normalizedExcludedWorkingDirectory
    }) else {
      return false
    }

    openWorkspace(group)

    if let workingDirectory = group.workingDirectory {
      requestScrollToProjectHeader(workingDirectory: workingDirectory)
    }

    return true
  }

  func clearProjectHeaderScrollRequest(_ request: ProjectHeaderScrollRequest) {
    guard projectHeaderScrollRequest == request else { return }
    projectHeaderScrollRequest = nil
  }

  public func selectDesignSystem(_ choice: EaselDesignSystemChoice) {
    selectedDesignSystem = choice
  }

  public func selectCodebase(_ url: URL) {
    selectedCodebasePath = url.standardizedFileURL.resolvingSymlinksInPath().path
    creationError = nil
  }

  public func clearCodebasePath() {
    selectedCodebasePath = nil
  }

  public func reportCodebaseSelectionFailure(_ error: Error) {
    creationError = error.localizedDescription
  }

  public func createPrototypeProject(fromPrompt prompt: String) async {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    selectedProjectKind = .prototype
    selectedFidelity = .highFidelity
    projectName = Self.suggestedProjectName(from: trimmed)
    requestHighFidelityContext()
  }

  public func requestHighFidelityContext() {
    guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    clearWireframeContextRequest()
    clearSlideDeckContextRequest()
    highFidelityContextRequest = HighFidelityProjectContextRequest()
  }

  func clearHighFidelityContextRequest() {
    highFidelityContextRequest = nil
  }

  func requestWireframeContext() {
    guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    clearHighFidelityContextRequest()
    clearSlideDeckContextRequest()
    wireframeContextRequest = WireframeProjectContextRequest()
  }

  func clearWireframeContextRequest() {
    wireframeContextRequest = nil
  }

  func requestSlideDeckContext() {
    guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    clearHighFidelityContextRequest()
    clearWireframeContextRequest()
    slideDeckContextRequest = SlideDeckProjectContextRequest()
  }

  func clearSlideDeckContextRequest() {
    slideDeckContextRequest = nil
  }

  func requestDesignSystemForHighFidelityContext() {
    shouldResumeHighFidelityContextAfterDesignSystemSelection = true
    clearHighFidelityContextRequest()
    requestBrowseDesignSystems()
  }

  public func consumeHighFidelityContextResumeRequest() -> Bool {
    let shouldResume = shouldResumeHighFidelityContextAfterDesignSystemSelection
    shouldResumeHighFidelityContextAfterDesignSystemSelection = false
    return shouldResume
  }

  func selectSession(_ session: StoredSession) {
    if isPendingNewSession(session) {
      selectedSessionId = session.id
      return
    }

    clearPendingNewSession()
    selectedSessionId = session.id
    onSessionSelected?(session)
  }

  func openWorkspace(_ group: ProjectGroup) {
    if let latestSession = group.sessions.first(where: { !isPendingNewSession($0) }) {
      clearPendingNewSession()
      selectedSessionId = latestSession.id
      onOpenWorkspace?(group.workingDirectory, latestSession)
    } else {
      preparePendingNewSession(workingDirectory: group.workingDirectory)
      onOpenWorkspace?(group.workingDirectory, nil)
    }
  }

  func requestNewChat(workingDirectory: String?) {
    preparePendingNewSession(workingDirectory: workingDirectory)
    onNewChatRequested?(workingDirectory)
  }

  func requestCreateDesignSystem() {
    onCreateDesignSystemRequested?()
  }

  func requestBrowseDesignSystems() {
    onBrowseDesignSystemsRequested?()
  }

  func deleteSession(_ session: StoredSession) {
    if isPendingNewSession(session) {
      clearPendingNewSession()
      return
    }

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

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async {
    designSystemError = nil

    do {
      try await designSystemManager.deleteDesignSystem(profile)

      let sessions = (try? await sessionStorage.getAllSessions()) ?? []
      let designSystemSessions = sessions.filter { $0.workingDirectory == profile.workingDirectory }

      for session in designSystemSessions {
        try? await sessionStorage.deleteSession(id: session.id)
        onDeleteSession?(session)
      }

      if designSystemSessions.contains(where: { $0.id == selectedSessionId }) {
        selectedSessionId = nil
      }

      if selectedDesignSystem.kind == .custom,
         selectedDesignSystem.referenceID == profile.id.uuidString {
        selectedDesignSystem = .preset(.none)
      }

      await loadSessions()
      onDesignSystemDeleted?()
    } catch {
      designSystemError = error.localizedDescription
    }
  }

  func createProjectAndStartSession(context: HighFidelityProjectContext = .empty) async {
    let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }

    clearHighFidelityContextRequest()
    clearWireframeContextRequest()
    clearSlideDeckContextRequest()
    isCreatingProject = true
    creationError = nil
    projectDeletionError = nil
    defer { isCreatingProject = false }

    let request = EaselProjectCreateRequest(
      name: name,
      kind: selectedProjectKind,
      designSystem: selectedDesignSystem,
      fidelity: projectCreationFidelity,
      codebasePath: projectCreationCodebasePath
    )

    do {
      let project = try await projectManager.createProject(from: request)
      do {
        try await attach(context, to: project)
      } catch {
        creationError = "Project created, but context could not be attached: \(error.localizedDescription)"
      }
      projectName = ""
      preparePendingNewSession(workingDirectory: project.workingDirectory)
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

      if selectedDesignSystem.kind == .custom,
         !availableDesignSystemChoices.contains(where: { $0.id == selectedDesignSystem.id }) {
        selectedDesignSystem = .preset(.none)
        designSystemError = "The selected design system could not be found."
      }
    } catch {
      customDesignSystems = []
      if selectedDesignSystem.kind == .custom {
        selectedDesignSystem = .preset(.none)
      }
      designSystemError = error.localizedDescription
    }
  }

  private func attach(_ context: HighFidelityProjectContext, to project: EaselDesignProject) async throws {
    if !context.resourceURLs.isEmpty {
      _ = try await resourceManager.importResources(
        from: context.resourceURLs,
        intoProjectAt: project.workingDirectory
      )
    }

    for codebaseURL in context.codebaseURLs {
      _ = try await resourceManager.importReferenceCodebase(
        from: codebaseURL,
        intoProjectAt: project.workingDirectory
      )
    }

    for textResource in context.textResources {
      _ = try await resourceManager.importTextResource(
        named: textResource.fileName,
        contents: textResource.contents,
        intoProjectAt: project.workingDirectory
      )
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

  private func replacePendingNewSession(with session: StoredSession) {
    let previousPendingSessionID = pendingNewSession?.id
    pendingNewSession = session
    selectedSessionId = session.id

    if let previousPendingSessionID, previousPendingSessionID != session.id {
      removeSessionFromLoadedGroups(id: previousPendingSessionID)
    }

    applyPendingNewSessionToLoadedGroups()
  }

  private func clearPendingNewSession() {
    guard let pendingNewSession else { return }

    self.pendingNewSession = nil
    removeSessionFromLoadedGroups(id: pendingNewSession.id)

    if selectedSessionId == pendingNewSession.id {
      selectedSessionId = nil
    }
  }

  private func sessionsIncludingPendingNewSession(_ sessions: [StoredSession]) -> [StoredSession] {
    guard let pendingNewSession else { return sessions }

    if sessions.contains(where: { $0.id == pendingNewSession.id }) {
      self.pendingNewSession = nil
      return sessions
    }

    if let replacementSession = sessions.first(where: { storedSession in
      Self.normalizedWorkingDirectory(storedSession.workingDirectory) == pendingNewSession.workingDirectory
        && storedSession.lastAccessedAt >= pendingNewSession.createdAt
    }) {
      self.pendingNewSession = nil
      if selectedSessionId == pendingNewSession.id {
        selectedSessionId = replacementSession.id
      }
      return sessions
    }

    return [pendingNewSession] + sessions
  }

  private func applyPendingNewSessionToLoadedGroups() {
    guard let pendingNewSession else { return }

    for index in projectGroups.indices {
      guard Self.normalizedWorkingDirectory(projectGroups[index].workingDirectory) == pendingNewSession.workingDirectory else {
        continue
      }

      projectGroups[index].sessions.removeAll { session in
        isPendingNewSession(session) || session.id == pendingNewSession.id
      }
      projectGroups[index].sessions.insert(pendingNewSession, at: 0)
      projectGroups[index].isExpanded = true
    }
  }

  private func removeSessionFromLoadedGroups(id sessionID: String) {
    for index in projectGroups.indices {
      projectGroups[index].sessions.removeAll { $0.id == sessionID }
    }
  }

  private func isPendingNewSession(_ session: StoredSession) -> Bool {
    pendingNewSession?.id == session.id
  }

  private static func normalizedWorkingDirectory(_ workingDirectory: String?) -> String? {
    let trimmed = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }
}

struct ProjectHeaderScrollRequest: Equatable, Sendable {
  let id = UUID()
  let projectGroupID: String
}
