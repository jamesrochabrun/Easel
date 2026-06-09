//
//  ProjectGroup.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation

struct ProjectGroup: Identifiable {
  let id: String
  let displayName: String
  let project: EaselDesignProject?
  let designSystem: EaselDesignSystemProfile?
  let workingDirectory: String?
  var sessions: [StoredSession]
  var isExpanded: Bool = true

  init(
    id: String,
    displayName: String,
    project: EaselDesignProject?,
    designSystem: EaselDesignSystemProfile? = nil,
    workingDirectory: String?,
    sessions: [StoredSession],
    isExpanded: Bool = true
  ) {
    self.id = id
    self.displayName = displayName
    self.project = project
    self.designSystem = designSystem
    self.workingDirectory = workingDirectory
    self.sessions = sessions
    self.isExpanded = isExpanded
  }

  var kind: EaselProjectKind? {
    project?.kind
  }

  var subtitle: String {
    var parts: [String] = []
    if let project {
      parts.append(project.kind.displayName)

      if project.kind == .prototype {
        parts.append(project.fidelity.displayName)
      }
    } else if designSystem != nil {
      parts.append("Design system")
    }

    let sessionLabel = sessions.count == 1 ? "1 session" : "\(sessions.count) sessions"
    parts.append(sessionLabel)
    return parts.joined(separator: " · ")
  }

  var designSystemChipTitle: String? {
    guard let project else { return nil }
    guard project.designSystem != .preset(.none) else { return nil }

    let displayName = project.designSystem.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    return displayName.isEmpty ? nil : displayName
  }

  func matchesSearchText(_ searchText: String) -> Bool {
    let query = Self.normalizedSearchText(searchText)
    guard !query.isEmpty else { return true }

    return Self.normalizedSearchText(displayName).contains(query)
  }

  static func groups(
    projects: [EaselDesignProject],
    designSystems: [EaselDesignSystemProfile] = [],
    sessions: [StoredSession],
    previousExpansion: [String: Bool]
  ) -> [ProjectGroup] {
    let sessionsByDirectory = Dictionary(grouping: sessions) { session in
      session.workingDirectory ?? "ungrouped"
    }

    let projectGroups = projects.map { project in
      ProjectGroup(
        id: project.workingDirectory,
        displayName: project.name,
        project: project,
        workingDirectory: project.workingDirectory,
        sessions: sortedSessions(sessionsByDirectory[project.workingDirectory] ?? []),
        isExpanded: previousExpansion[project.workingDirectory] ?? true
      )
    }

    // Design systems are workspaces too: surface each as its own row so it's
    // visible (and returnable) right after creation. Skip any whose folder is
    // already represented by a managed project to avoid duplicate rows.
    let projectDirectories = Set(projects.map(\.workingDirectory))
    let designSystemGroups = designSystems
      .filter { !projectDirectories.contains($0.workingDirectory) }
      .map { designSystem in
        ProjectGroup(
          id: designSystem.workingDirectory,
          displayName: designSystem.name,
          project: nil,
          designSystem: designSystem,
          workingDirectory: designSystem.workingDirectory,
          sessions: sortedSessions(sessionsByDirectory[designSystem.workingDirectory] ?? []),
          isExpanded: previousExpansion[designSystem.workingDirectory] ?? true
        )
      }

    // Most recently active workspace first, so newly created/used projects and
    // design systems bubble to the top of the list.
    return (projectGroups + designSystemGroups).sorted { lhs, rhs in
      lastActivity(of: lhs) > lastActivity(of: rhs)
    }
  }

  private static func lastActivity(of group: ProjectGroup) -> Date {
    let sessionDate = group.sessions.map(\.lastAccessedAt).max()
    let workspaceDate = group.project?.updatedAt ?? group.designSystem?.updatedAt
    return [sessionDate, workspaceDate].compactMap { $0 }.max() ?? .distantPast
  }

  private static func sortedSessions(_ sessions: [StoredSession]) -> [StoredSession] {
    sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }

  private static func normalizedSearchText(_ value: String) -> String {
    value
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }
}
