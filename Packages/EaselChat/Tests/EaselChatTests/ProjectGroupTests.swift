//
//  ProjectGroupTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import ClaudeCodeCore
@testable import EaselChat

struct ProjectGroupTests {

  @Test
  func groupsIgnoreLegacySessionsWithoutManagedProjects() {
    let legacySession = StoredSession(
      id: "legacy",
      createdAt: Date(),
      firstUserMessage: "Old project",
      lastAccessedAt: Date(),
      workingDirectory: "/tmp/old-project"
    )

    let groups = ProjectGroup.groups(
      projects: [],
      sessions: [legacySession],
      previousExpansion: [:]
    )

    #expect(groups.isEmpty)
  }

  @Test
  func groupsAttachSessionsOnlyToMatchingManagedProjectFolders() {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Checkout",
      kind: .prototype,
      designSystem: .airbnb,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/checkout",
      createdAt: Date(),
      updatedAt: Date()
    )
    let matchingSession = StoredSession(
      id: "matching",
      createdAt: Date(),
      firstUserMessage: "Build checkout",
      lastAccessedAt: Date(),
      workingDirectory: "/tmp/checkout"
    )
    let legacySession = StoredSession(
      id: "legacy",
      createdAt: Date(),
      firstUserMessage: "Old project",
      lastAccessedAt: Date(),
      workingDirectory: "/tmp/old-project"
    )

    let groups = ProjectGroup.groups(
      projects: [project],
      sessions: [matchingSession, legacySession],
      previousExpansion: [:]
    )

    #expect(groups.count == 1)
    #expect(groups.first?.displayName == "Checkout")
    #expect(groups.first?.sessions.map(\.id) == ["matching"])
  }
}
