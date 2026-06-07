//
//  DesignLibraryViewModelTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation
import Testing
@testable import EaselChat

@MainActor
struct DesignLibraryViewModelTests {
  @Test
  func refreshLoadsProjectsDesignSystemsAndLatestSessionsByDirectory() async throws {
    let rootURL = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let projectURL = try makeDirectory(named: "checkout", in: rootURL)
    let designSystemURL = try makeDirectory(named: "brand-system", in: rootURL)
    let projectUpdatedAt = Date(timeIntervalSince1970: 100)
    let designSystemUpdatedAt = Date(timeIntervalSince1970: 300)
    let latestSessionDate = Date(timeIntervalSince1970: 500)

    let project = makeProject(
      name: "Checkout",
      kind: .prototype,
      path: projectURL.path,
      updatedAt: projectUpdatedAt
    )
    let designSystem = makeDesignSystem(
      name: "Brand System",
      path: designSystemURL.path,
      updatedAt: designSystemUpdatedAt
    )
    let olderSession = makeSession(
      id: "older",
      path: project.workingDirectory,
      lastAccessedAt: Date(timeIntervalSince1970: 200)
    )
    let latestSession = makeSession(
      id: "latest",
      path: project.workingDirectory,
      lastAccessedAt: latestSessionDate
    )

    let viewModel = DesignLibraryViewModel(
      sessionStorage: DesignLibrarySessionStorageStub(sessions: [olderSession, latestSession]),
      projectManager: DesignLibraryProjectManagerStub(projects: [project]),
      designSystemManager: DesignLibraryDesignSystemManagerStub(profiles: [designSystem])
    )

    await viewModel.refresh()

    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.items.map(\.title) == ["Checkout", "Brand System"])
    #expect(viewModel.items.first?.latestSession?.id == "latest")
    #expect(viewModel.items.first?.activityDate == latestSessionDate)
    #expect(viewModel.items.first?.previewFile?.url.lastPathComponent == "index.html")
    #expect(viewModel.items.last?.kind == .designSystem)
  }

  @Test
  func refreshSortsByTitleWhenActivityDatesMatch() async throws {
    let rootURL = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let updatedAt = Date(timeIntervalSince1970: 100)
    let alphaURL = try makeDirectory(named: "alpha", in: rootURL)
    let betaURL = try makeDirectory(named: "beta", in: rootURL)
    let alpha = makeProject(name: "Alpha", kind: .prototype, path: alphaURL.path, updatedAt: updatedAt)
    let beta = makeProject(name: "Beta", kind: .slideDeck, path: betaURL.path, updatedAt: updatedAt)

    let viewModel = DesignLibraryViewModel(
      sessionStorage: DesignLibrarySessionStorageStub(sessions: []),
      projectManager: DesignLibraryProjectManagerStub(projects: [beta, alpha]),
      designSystemManager: DesignLibraryDesignSystemManagerStub(profiles: [])
    )

    await viewModel.refresh()

    #expect(viewModel.items.map(\.title) == ["Alpha", "Beta"])
    #expect(viewModel.items.map(\.kind) == [.prototype, .slideDeck])
  }

  @Test
  func refreshReportsPartialFailuresAndKeepsAvailableItems() async throws {
    let rootURL = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let designSystemURL = try makeDirectory(named: "brand-system", in: rootURL)
    let designSystem = makeDesignSystem(
      name: "Brand System",
      path: designSystemURL.path,
      updatedAt: Date(timeIntervalSince1970: 100)
    )

    let viewModel = DesignLibraryViewModel(
      sessionStorage: DesignLibrarySessionStorageStub(sessions: []),
      projectManager: DesignLibraryProjectManagerStub(error: DesignLibraryStubError.loadFailed),
      designSystemManager: DesignLibraryDesignSystemManagerStub(profiles: [designSystem])
    )

    await viewModel.refresh()

    #expect(viewModel.items.map(\.title) == ["Brand System"])
    #expect(viewModel.errorMessage?.contains("Projects:") == true)
  }

  @Test
  func deleteDesignSystemRemovesItemDeletesSessionsAndNotifies() async throws {
    let rootURL = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let keepURL = try makeDirectory(named: "keep-system", in: rootURL)
    let dropURL = try makeDirectory(named: "drop-system", in: rootURL)
    let keep = makeDesignSystem(name: "Keep", path: keepURL.path, updatedAt: Date(timeIntervalSince1970: 100))
    let drop = makeDesignSystem(name: "Drop", path: dropURL.path, updatedAt: Date(timeIntervalSince1970: 200))
    let dropSession = makeSession(id: "drop-session", path: drop.workingDirectory, lastAccessedAt: Date(timeIntervalSince1970: 250))
    let keepSession = makeSession(id: "keep-session", path: keep.workingDirectory, lastAccessedAt: Date(timeIntervalSince1970: 150))

    let designSystemStub = DesignLibraryDesignSystemManagerStub(profiles: [keep, drop])
    let sessionStub = DesignLibrarySessionStorageStub(sessions: [dropSession, keepSession])
    let viewModel = DesignLibraryViewModel(
      sessionStorage: sessionStub,
      projectManager: DesignLibraryProjectManagerStub(projects: []),
      designSystemManager: designSystemStub
    )

    await viewModel.refresh()
    #expect(viewModel.items.map(\.title) == ["Drop", "Keep"])

    var notifiedID: UUID?
    viewModel.onDesignSystemDeleted = { notifiedID = $0.id }

    await viewModel.deleteDesignSystem(drop)

    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.items.map(\.title) == ["Keep"])
    #expect(await designSystemStub.deletedProfileIDs == [drop.id])
    #expect(await sessionStub.deletedSessionIDs == ["drop-session"])
    #expect(notifiedID == drop.id)
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("DesignLibraryViewModelTests-\(UUID().uuidString)", isDirectory: true)
  }

  private func makeDirectory(named name: String, in rootURL: URL) throws -> URL {
    let directoryURL = rootURL.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try Data("<!doctype html><title>\(name)</title>".utf8)
      .write(to: directoryURL.appendingPathComponent("index.html"))
    return directoryURL
  }

  private func makeProject(
    name: String,
    kind: EaselProjectKind,
    path: String,
    updatedAt: Date
  ) -> EaselDesignProject {
    EaselDesignProject(
      id: UUID(),
      name: name,
      kind: kind,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: path,
      createdAt: updatedAt,
      updatedAt: updatedAt
    )
  }

  private func makeDesignSystem(
    name: String,
    path: String,
    updatedAt: Date
  ) -> EaselDesignSystemProfile {
    EaselDesignSystemProfile(
      id: UUID(),
      name: name,
      blurb: "\(name) components",
      notes: "",
      sourceLinks: [],
      workingDirectory: path,
      createdAt: updatedAt,
      updatedAt: updatedAt
    )
  }

  private func makeSession(
    id: String,
    path: String,
    lastAccessedAt: Date
  ) -> StoredSession {
    StoredSession(
      id: id,
      createdAt: lastAccessedAt,
      firstUserMessage: id,
      lastAccessedAt: lastAccessedAt,
      workingDirectory: path
    )
  }
}

private enum DesignLibraryStubError: Error {
  case loadFailed
}

private actor DesignLibraryProjectManagerStub: EaselProjectManaging {
  private let projects: [EaselDesignProject]
  private let error: Error?

  init(projects: [EaselDesignProject] = [], error: Error? = nil) {
    self.projects = projects
    self.error = error
  }

  func loadProjects() async throws -> [EaselDesignProject] {
    if let error {
      throw error
    }
    return projects
  }

  func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject {
    projects[0]
  }

  func deleteProject(_ project: EaselDesignProject) async throws {}
}

private actor DesignLibraryDesignSystemManagerStub: EaselDesignSystemManaging {
  private var profiles: [EaselDesignSystemProfile]
  private(set) var deletedProfileIDs: [UUID] = []

  init(profiles: [EaselDesignSystemProfile]) {
    self.profiles = profiles
  }

  func loadDesignSystems() async throws -> [EaselDesignSystemProfile] {
    profiles
  }

  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    profiles[0]
  }

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    nil
  }

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {
    deletedProfileIDs.append(profile.id)
    profiles.removeAll { $0.id == profile.id }
  }
}

private actor DesignLibrarySessionStorageStub: SessionStorageProtocol {
  private var sessions: [StoredSession]
  private(set) var deletedSessionIDs: [String] = []

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
    deletedSessionIDs.append(id)
    sessions.removeAll { $0.id == id }
  }

  func deleteAllSessions() async throws {}

  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {}

  func updateSessionId(oldId: String, newId: String) async throws {}
}
