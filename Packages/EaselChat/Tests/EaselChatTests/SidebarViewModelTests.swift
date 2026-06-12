//
//  SidebarViewModelTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

@MainActor
struct SidebarViewModelTests {

  @Test
  func creatingProjectLaunchesEmptyChatForProject() async {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Manhattan",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe,
      workingDirectory: "/tmp/manhattan",
      createdAt: Date(),
      updatedAt: Date()
    )
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(project: project),
      designSystemManager: SidebarDesignSystemManagerStub()
    )
    viewModel.projectName = "Manhattan"

    var launchedProject: EaselProjectLaunch?
    viewModel.onProjectLaunchRequested = { launch in
      launchedProject = launch
    }

    await viewModel.createProjectAndStartSession()

    #expect(launchedProject?.project == project)
  }

  @Test
  func creatingSlideDeckUsesHighFidelityWhenFidelityPickerIsHidden() async {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Roadmap",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/roadmap",
      createdAt: Date(),
      updatedAt: Date()
    )
    let projectManager = SidebarProjectManagerStub(project: project)
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: projectManager,
      designSystemManager: SidebarDesignSystemManagerStub()
    )
    viewModel.selectedProjectKind = .slideDeck
    viewModel.selectedFidelity = .wireframe
    viewModel.projectName = "Roadmap"

    await viewModel.createProjectAndStartSession()

    let requests = await projectManager.createdRequests()
    #expect(viewModel.shouldShowFidelityPicker == false)
    #expect(requests.first?.kind == .slideDeck)
    #expect(requests.first?.fidelity == .highFidelity)
  }

  @Test
  func designSystemChoicesExcludeUnbackedBuiltInPresets() async {
    let customSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "AgentHub Design System",
      blurb: "AgentHub product UI",
      notes: "",
      sourceLinks: [],
      workingDirectory: "/tmp/agenthub-design-system",
      createdAt: Date(),
      updatedAt: Date()
    )
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(projects: []),
      designSystemManager: SidebarDesignSystemManagerStub(profiles: [customSystem])
    )

    await viewModel.loadSessions()

    #expect(viewModel.selectedDesignSystem == .preset(.none))
    #expect(viewModel.shouldShowCreateOnlyDesignSystemControl == false)
    #expect(viewModel.availableDesignSystemChoices.map(\.displayName) == [
      "No design system",
      "AgentHub Design System",
    ])
  }

  @Test
  func designSystemControlShowsOnlyCreateWhenNoCustomSystemsExist() async {
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(projects: []),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()

    #expect(viewModel.selectedDesignSystem == .preset(.none))
    #expect(viewModel.shouldShowCreateOnlyDesignSystemControl)
  }

  @Test
  func requestingNewChatShowsPendingSessionRowImmediately() async throws {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Landing page",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/landing-page",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let viewModel = SidebarViewModel(
      sessionStorage: RecordingSessionStorage(sessions: []),
      projectManager: SidebarProjectManagerStub(projects: [project]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()
    viewModel.requestNewChat(workingDirectory: project.workingDirectory)

    let projectGroup = try #require(viewModel.projectGroups.first)
    let pendingSession = try #require(projectGroup.sessions.first)
    #expect(pendingSession.firstUserMessage.isEmpty)
    #expect(pendingSession.workingDirectory == project.workingDirectory)
    #expect(viewModel.selectedSessionId == pendingSession.id)
    #expect(projectGroup.isExpanded)
  }

  @Test
  func pendingNewChatSurvivesSessionReloadUntilRuntimeSessionExists() async throws {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Landing page",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/landing-page",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let viewModel = SidebarViewModel(
      sessionStorage: RecordingSessionStorage(sessions: []),
      projectManager: SidebarProjectManagerStub(projects: [project]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()
    viewModel.requestNewChat(workingDirectory: project.workingDirectory)
    let pendingID = try #require(viewModel.selectedSessionId)

    await viewModel.loadSessions()

    let projectGroup = try #require(viewModel.projectGroups.first)
    #expect(projectGroup.sessions.map(\.id) == [pendingID])
    #expect(viewModel.selectedSessionId == pendingID)
  }

  @Test
  func completingPendingNewChatKeepsRowSelectedUntilStoredSessionLoads() async throws {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Landing page",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/landing-page",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let sessionStorage = RecordingSessionStorage(sessions: [])
    let viewModel = SidebarViewModel(
      sessionStorage: sessionStorage,
      projectManager: SidebarProjectManagerStub(projects: [project]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()
    viewModel.requestNewChat(workingDirectory: project.workingDirectory)
    viewModel.completePendingNewSession(sessionId: "runtime-session")
    await viewModel.loadSessions()

    var projectGroup = try #require(viewModel.projectGroups.first)
    #expect(projectGroup.sessions.map(\.id) == ["runtime-session"])
    #expect(viewModel.selectedSessionId == "runtime-session")

    let storedSession = StoredSession(
      id: "runtime-session",
      createdAt: Date(timeIntervalSince1970: 2),
      firstUserMessage: "Build the landing page",
      lastAccessedAt: Date(timeIntervalSince1970: 3),
      workingDirectory: project.workingDirectory
    )
    await sessionStorage.replaceSessions([storedSession])
    await viewModel.loadSessions()

    projectGroup = try #require(viewModel.projectGroups.first)
    #expect(projectGroup.sessions.map(\.id) == ["runtime-session"])
    #expect(projectGroup.sessions.first?.firstUserMessage == "Build the landing page")
    #expect(viewModel.selectedSessionId == "runtime-session")
  }

  @Test
  func filteredProjectGroupsMatchesProjectNamesOnly() async {
    let checkout = EaselDesignProject(
      id: UUID(),
      name: "Checkout Flow",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/checkout-flow",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let roadmap = EaselDesignProject(
      id: UUID(),
      name: "Roadmap Deck",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/roadmap-deck",
      createdAt: Date(timeIntervalSince1970: 2),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let session = StoredSession(
      id: "checkout-session",
      createdAt: Date(timeIntervalSince1970: 3),
      firstUserMessage: "Review payment states",
      lastAccessedAt: Date(timeIntervalSince1970: 3),
      workingDirectory: checkout.workingDirectory
    )
    let viewModel = SidebarViewModel(
      sessionStorage: RecordingSessionStorage(sessions: [session]),
      projectManager: SidebarProjectManagerStub(projects: [checkout, roadmap]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()
    #expect(viewModel.filteredProjectGroups.map(\.displayName).sorted() == [
      "Checkout Flow",
      "Roadmap Deck",
    ])

    viewModel.projectSearchText = "payment states"
    #expect(viewModel.filteredProjectGroups.isEmpty)

    viewModel.projectSearchText = "checkout"
    #expect(viewModel.filteredProjectGroups.map(\.displayName) == ["Checkout Flow"])

    viewModel.projectSearchText = "slide deck"
    #expect(viewModel.filteredProjectGroups.isEmpty)

    viewModel.projectSearchText = "roadmap"
    #expect(viewModel.filteredProjectGroups.map(\.displayName) == ["Roadmap Deck"])

    viewModel.projectSearchText = "missing"
    #expect(viewModel.filteredProjectGroups.isEmpty)
  }

  @Test
  func requestingProjectHeaderScrollCreatesFreshRequestEachTime() throws {
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(projects: []),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    viewModel.requestScrollToProjectHeader(workingDirectory: "  /tmp/checkout  ")
    let firstRequest = try #require(viewModel.projectHeaderScrollRequest)

    viewModel.requestScrollToProjectHeader(workingDirectory: "/tmp/checkout")
    let secondRequest = try #require(viewModel.projectHeaderScrollRequest)

    #expect(firstRequest.projectGroupID == "/tmp/checkout")
    #expect(secondRequest.projectGroupID == "/tmp/checkout")
    #expect(firstRequest.id != secondRequest.id)
  }

  @Test
  func clearingProjectHeaderScrollRequestIgnoresStaleRequest() throws {
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(projects: []),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    viewModel.requestScrollToProjectHeader(workingDirectory: "/tmp/checkout")
    let staleRequest = try #require(viewModel.projectHeaderScrollRequest)
    viewModel.requestScrollToProjectHeader(workingDirectory: "/tmp/roadmap")
    let currentRequest = try #require(viewModel.projectHeaderScrollRequest)

    viewModel.clearProjectHeaderScrollRequest(staleRequest)
    #expect(viewModel.projectHeaderScrollRequest == currentRequest)

    viewModel.clearProjectHeaderScrollRequest(currentRequest)
    #expect(viewModel.projectHeaderScrollRequest == nil)
  }

  @Test
  func openingFirstWorkspaceExcludingDeletedWorkspaceSelectsNextGroup() async throws {
    let deletedProject = EaselDesignProject(
      id: UUID(),
      name: "Deleted",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/deleted",
      createdAt: Date(timeIntervalSince1970: 3),
      updatedAt: Date(timeIntervalSince1970: 3)
    )
    let nextProject = EaselDesignProject(
      id: UUID(),
      name: "Next",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/next",
      createdAt: Date(timeIntervalSince1970: 2),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let nextSession = StoredSession(
      id: "next-session",
      createdAt: Date(timeIntervalSince1970: 4),
      firstUserMessage: "Continue",
      lastAccessedAt: Date(timeIntervalSince1970: 4),
      workingDirectory: nextProject.workingDirectory
    )
    let viewModel = SidebarViewModel(
      sessionStorage: RecordingSessionStorage(sessions: [nextSession]),
      projectManager: SidebarProjectManagerStub(projects: [deletedProject, nextProject]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    var openedWorkingDirectory: String?
    var openedSessionID: String?
    viewModel.onOpenWorkspace = { workingDirectory, latestSession in
      openedWorkingDirectory = workingDirectory
      openedSessionID = latestSession?.id
    }

    await viewModel.loadSessions()
    let didOpen = viewModel.openFirstWorkspace(excluding: deletedProject.workingDirectory)

    #expect(didOpen)
    #expect(openedWorkingDirectory == nextProject.workingDirectory)
    #expect(openedSessionID == nextSession.id)
    #expect(viewModel.selectedSessionId == nextSession.id)
    #expect(viewModel.projectHeaderScrollRequest?.projectGroupID == nextProject.workingDirectory)
  }

  @Test
  func openingFirstWorkspaceReturnsFalseWhenNoReplacementExists() async {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Only",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/only",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let viewModel = SidebarViewModel(
      sessionStorage: RecordingSessionStorage(sessions: []),
      projectManager: SidebarProjectManagerStub(projects: [project]),
      designSystemManager: SidebarDesignSystemManagerStub()
    )

    await viewModel.loadSessions()

    #expect(viewModel.containsWorkspace(workingDirectory: project.workingDirectory))
    #expect(viewModel.openFirstWorkspace(excluding: project.workingDirectory) == false)
  }

  @Test
  func deletingProjectDeletesStoredSessionsAndReloadsProjects() async throws {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Archive",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/archive",
      createdAt: Date(),
      updatedAt: Date()
    )
    let session = StoredSession(
      id: "session-1",
      createdAt: Date(),
      firstUserMessage: "Build archive",
      lastAccessedAt: Date(),
      workingDirectory: project.workingDirectory
    )
    let sessionStorage = RecordingSessionStorage(sessions: [session])
    let projectManager = SidebarProjectManagerStub(projects: [project])
    let viewModel = SidebarViewModel(
      sessionStorage: sessionStorage,
      projectManager: projectManager,
      designSystemManager: SidebarDesignSystemManagerStub()
    )
    viewModel.selectedSessionId = session.id

    var callbackDeletedSessionIDs: [String] = []
    viewModel.onDeleteSession = { deletedSession in
      callbackDeletedSessionIDs.append(deletedSession.id)
    }

    await viewModel.loadSessions()
    let projectGroup = try #require(viewModel.projectGroups.first)
    await viewModel.deleteProject(projectGroup)

    #expect(await projectManager.deletedProjectIDs() == [project.id])
    #expect(await sessionStorage.deletedSessionIDs() == [session.id])
    #expect(callbackDeletedSessionIDs == [session.id])
    #expect(viewModel.selectedSessionId == nil)
    #expect(viewModel.projectGroups.isEmpty)
  }

  @Test
  func deletingSelectedDesignSystemRemovesSessionsAndResetsSelection() async throws {
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Brand System",
      blurb: "Brand System components",
      notes: "",
      sourceLinks: [],
      workingDirectory: "/tmp/brand-system",
      createdAt: Date(),
      updatedAt: Date()
    )
    let session = StoredSession(
      id: "design-system-session",
      createdAt: Date(),
      firstUserMessage: "Generate tokens",
      lastAccessedAt: Date(),
      workingDirectory: designSystem.workingDirectory
    )
    let sessionStorage = RecordingSessionStorage(sessions: [session])
    let designSystemManager = SidebarDesignSystemManagerStub(profiles: [designSystem])
    let viewModel = SidebarViewModel(
      sessionStorage: sessionStorage,
      projectManager: SidebarProjectManagerStub(projects: []),
      designSystemManager: designSystemManager
    )
    viewModel.selectedDesignSystem = .custom(designSystem)
    viewModel.selectedSessionId = session.id

    var callbackDeletedSessionIDs: [String] = []
    var didCallDesignSystemDeleted = false
    viewModel.onDeleteSession = { deletedSession in
      callbackDeletedSessionIDs.append(deletedSession.id)
    }
    viewModel.onDesignSystemDeleted = {
      didCallDesignSystemDeleted = true
    }

    await viewModel.loadSessions()
    await viewModel.deleteDesignSystem(designSystem)

    #expect(await designSystemManager.deletedDesignSystemIDs() == [designSystem.id])
    #expect(await sessionStorage.deletedSessionIDs() == [session.id])
    #expect(callbackDeletedSessionIDs == [session.id])
    #expect(didCallDesignSystemDeleted)
    #expect(viewModel.selectedSessionId == nil)
    #expect(viewModel.selectedDesignSystem == .preset(.none))
    #expect(viewModel.customDesignSystems.isEmpty)
  }
}

private actor SidebarDesignSystemManagerStub: EaselDesignSystemManaging {
  private var profiles: [EaselDesignSystemProfile]
  private var deletedIDs: [UUID] = []

  init(profiles: [EaselDesignSystemProfile] = []) {
    self.profiles = profiles
  }

  func loadDesignSystems() async throws -> [EaselDesignSystemProfile] {
    profiles
  }

  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    EaselDesignSystemProfile(
      id: UUID(),
      name: "Stub",
      blurb: request.blurb,
      notes: request.notes,
      sourceLinks: request.sourceLinks,
      workingDirectory: "/tmp/stub",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {
    deletedIDs.append(profile.id)
    profiles.removeAll { $0.id == profile.id }
  }

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    nil
  }

  func deletedDesignSystemIDs() -> [UUID] {
    deletedIDs
  }
}

private actor SidebarProjectManagerStub: EaselProjectManaging {
  private var projects: [EaselDesignProject]
  private var deletedIDs: [UUID] = []
  private var createRequests: [EaselProjectCreateRequest] = []

  init(project: EaselDesignProject) {
    self.projects = [project]
  }

  init(projects: [EaselDesignProject]) {
    self.projects = projects
  }

  func loadProjects() async throws -> [EaselDesignProject] {
    projects
  }

  func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject {
    createRequests.append(request)
    return projects[0]
  }

  func deleteProject(_ project: EaselDesignProject) async throws {
    deletedIDs.append(project.id)
    projects.removeAll { $0.id == project.id }
  }

  func deletedProjectIDs() -> [UUID] {
    deletedIDs
  }

  func createdRequests() -> [EaselProjectCreateRequest] {
    createRequests
  }
}

private actor RecordingSessionStorage: SessionStorageProtocol {
  private var sessions: [StoredSession]
  private var deletedIDs: [String] = []

  init(sessions: [StoredSession]) {
    self.sessions = sessions
  }

  func saveSession(
    id: String,
    firstMessage: String,
    workingDirectory: String?,
    branchName: String?,
    isWorktree: Bool
  ) async throws {}

  func getAllSessions() async throws -> [StoredSession] {
    sessions
  }

  func getSession(id: String) async throws -> StoredSession? {
    sessions.first { $0.id == id }
  }

  func updateLastAccessed(id: String) async throws {}

  func deleteSession(id: String) async throws {
    deletedIDs.append(id)
    sessions.removeAll { $0.id == id }
  }

  func deleteAllSessions() async throws {
    deletedIDs.append(contentsOf: sessions.map(\.id))
    sessions = []
  }

  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {}

  func updateSessionId(oldId: String, newId: String) async throws {}

  func deletedSessionIDs() -> [String] {
    deletedIDs
  }

  func replaceSessions(_ sessions: [StoredSession]) {
    self.sessions = sessions
  }
}
