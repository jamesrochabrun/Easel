//
//  SidebarViewModelTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import Foundation
import Testing
@testable import EaselChat

@MainActor
struct SidebarViewModelTests {

  @Test
  func creatingProjectLaunchesEmptyConversation() async {
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
      projectManager: SidebarProjectManagerStub(project: project)
    )
    viewModel.projectName = "Manhattan"

    var launchedProject: EaselProjectLaunch?
    viewModel.onProjectLaunchRequested = { launch in
      launchedProject = launch
    }

    await viewModel.createProjectAndStartSession(seedPrompt: "Create a Manhattan planning dashboard")

    #expect(launchedProject?.project == project)
    #expect(launchedProject?.prompt == "")
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
      projectManager: projectManager
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

private actor SidebarProjectManagerStub: EaselProjectManaging {
  private var projects: [EaselDesignProject]
  private var deletedIDs: [UUID] = []

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
    projects[0]
  }

  func deleteProject(_ project: EaselDesignProject) async throws {
    deletedIDs.append(project.id)
    projects.removeAll { $0.id == project.id }
  }

  func deletedProjectIDs() -> [UUID] {
    deletedIDs
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
