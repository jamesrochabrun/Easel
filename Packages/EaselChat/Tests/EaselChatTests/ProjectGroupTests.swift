//
//  ProjectGroupTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import ClaudeCodeCore
import EaselDesignSystems
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
      designSystem: .none,
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

  @Test
  func groupsSurfaceDesignSystemsAsRows() {
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Plus UI",
      blurb: "Plus UI kit",
      notes: "",
      sourceLinks: [],
      workingDirectory: "/tmp/plusui",
      createdAt: Date(),
      updatedAt: Date()
    )
    let session = StoredSession(
      id: "ds-session",
      createdAt: Date(),
      firstUserMessage: "Use Plus UI",
      lastAccessedAt: Date(),
      workingDirectory: "/tmp/plusui"
    )

    let groups = ProjectGroup.groups(
      projects: [],
      designSystems: [designSystem],
      sessions: [session],
      previousExpansion: [:]
    )

    #expect(groups.count == 1)
    #expect(groups.first?.displayName == "Plus UI")
    #expect(groups.first?.project == nil)
    #expect(groups.first?.designSystem?.id == designSystem.id)
    #expect(groups.first?.sessions.map(\.id) == ["ds-session"])
    #expect(groups.first?.subtitle.contains("Design system") == true)
  }

  @Test
  func subtitleIncludesFidelityOnlyForPrototypes() {
    let prototype = EaselDesignProject(
      id: UUID(),
      name: "Checkout",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe,
      workingDirectory: "/tmp/checkout",
      createdAt: Date(),
      updatedAt: Date()
    )
    let deck = EaselDesignProject(
      id: UUID(),
      name: "Roadmap",
      kind: .slideDeck,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/roadmap",
      createdAt: Date(),
      updatedAt: Date()
    )

    let prototypeGroup = ProjectGroup(
      id: prototype.workingDirectory,
      displayName: prototype.name,
      project: prototype,
      workingDirectory: prototype.workingDirectory,
      sessions: []
    )
    let deckGroup = ProjectGroup(
      id: deck.workingDirectory,
      displayName: deck.name,
      project: deck,
      workingDirectory: deck.workingDirectory,
      sessions: []
    )

    #expect(prototypeGroup.subtitle.contains("Prototype"))
    #expect(prototypeGroup.subtitle.contains("Wireframe"))
    #expect(prototypeGroup.subtitle.contains("0 sessions"))
    #expect(deckGroup.subtitle.contains("Slide deck"))
    #expect(deckGroup.subtitle.contains("High fidelity") == false)
    #expect(deckGroup.subtitle.contains("0 sessions"))
  }

  @Test
  func designSystemChipTitleUsesCustomDesignSystemNameForProjectRows() {
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Acme UI",
      blurb: "Acme components",
      notes: "",
      sourceLinks: [],
      workingDirectory: "/tmp/acme-ui",
      createdAt: Date(),
      updatedAt: Date()
    )
    let project = EaselDesignProject(
      id: UUID(),
      name: "Checkout",
      kind: .prototype,
      designSystem: .custom(designSystem),
      fidelity: .highFidelity,
      workingDirectory: "/tmp/checkout",
      createdAt: Date(),
      updatedAt: Date()
    )
    let group = ProjectGroup(
      id: project.workingDirectory,
      displayName: project.name,
      project: project,
      workingDirectory: project.workingDirectory,
      sessions: []
    )

    #expect(group.designSystemChipTitle == "Acme UI")
  }

  @Test
  func designSystemChipTitleSkipsProjectsWithoutDesignSystem() {
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
    let group = ProjectGroup(
      id: project.workingDirectory,
      displayName: project.name,
      project: project,
      workingDirectory: project.workingDirectory,
      sessions: []
    )

    #expect(group.designSystemChipTitle == nil)
  }

  @Test
  func searchMatchesProjectNameOnly() {
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Acme UI",
      blurb: "Acme components",
      notes: "",
      sourceLinks: [],
      workingDirectory: "/tmp/acme-ui",
      createdAt: Date(),
      updatedAt: Date()
    )
    let project = EaselDesignProject(
      id: UUID(),
      name: "Checkout",
      kind: .prototype,
      designSystem: .custom(designSystem),
      fidelity: .highFidelity,
      workingDirectory: "/tmp/checkout",
      createdAt: Date(),
      updatedAt: Date()
    )
    let session = StoredSession(
      id: "payment-session",
      createdAt: Date(),
      firstUserMessage: "Review payment states",
      lastAccessedAt: Date(),
      workingDirectory: project.workingDirectory
    )
    let group = ProjectGroup(
      id: project.workingDirectory,
      displayName: project.name,
      project: project,
      workingDirectory: project.workingDirectory,
      sessions: [session]
    )

    #expect(group.matchesSearchText("checkout"))
    #expect(group.matchesSearchText("CHECK"))
    #expect(group.matchesSearchText("prototype") == false)
    #expect(group.matchesSearchText("high fidelity") == false)
    #expect(group.matchesSearchText("acme") == false)
    #expect(group.matchesSearchText("payment states") == false)
    #expect(group.matchesSearchText("missing") == false)
  }

  @Test
  func searchMatchesDesignSystemRowNameOnly() {
    let designSystem = EaselDesignSystemProfile(
      id: UUID(),
      name: "Apple",
      blurb: "Spatial interface kit",
      notes: "Vision layouts",
      sourceLinks: ["https://developer.apple.com/design"],
      workingDirectory: "/tmp/apple-design-system",
      createdAt: Date(),
      updatedAt: Date()
    )
    let group = ProjectGroup(
      id: designSystem.workingDirectory,
      displayName: designSystem.name,
      project: nil,
      designSystem: designSystem,
      workingDirectory: designSystem.workingDirectory,
      sessions: []
    )

    #expect(group.matchesSearchText("apple"))
    #expect(group.matchesSearchText("spatial") == false)
    #expect(group.matchesSearchText("developer.apple") == false)
    #expect(group.matchesSearchText("checkout") == false)
  }
}
