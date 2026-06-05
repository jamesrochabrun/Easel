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
  func deletingProjectDeletesStoredSessionsAndReloadsProjects() async throws {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Archive",
      kind: .prototype,
      designSystem: .airbnb,
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
}

private actor SidebarDesignSystemManagerStub: EaselDesignSystemManaging {
  private let profiles: [EaselDesignSystemProfile]

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

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    nil
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
    projects[0]
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
}
