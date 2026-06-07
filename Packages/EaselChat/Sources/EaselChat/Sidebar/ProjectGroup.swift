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

  var systemImage: String {
    if designSystem != nil {
      return "square.grid.2x2"
    }

    return kind?.systemImage ?? (isExpanded ? "folder.fill" : "folder")
  }

  var canDelete: Bool {
    project != nil
  }

  var subtitle: String {
    var parts: [String] = []
    if let project {
      parts.append(project.kind.displayName)

      if project.kind == .prototype {
        parts.append(project.fidelity.displayName)
      }

      let designSystemNames = project.designSystems
        .filter { !$0.isNone }
        .map(\.displayName)
      if !designSystemNames.isEmpty {
        parts.append(designSystemNames.joined(separator: " + "))
      }
    } else if designSystem != nil {
      parts.append("Design system")
    }

    let sessionLabel = sessions.count == 1 ? "1 session" : "\(sessions.count) sessions"
    parts.append(sessionLabel)
    return parts.joined(separator: " · ")
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

    let designSystemGroups = designSystems.map { designSystem in
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

    return (projectGroups + designSystemGroups).sorted(by: sortGroups)
  }

  private static func sortedSessions(_ sessions: [StoredSession]) -> [StoredSession] {
    sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }

  private static func sortGroups(_ lhs: ProjectGroup, _ rhs: ProjectGroup) -> Bool {
    if lhs.activityDate == rhs.activityDate {
      return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    return lhs.activityDate > rhs.activityDate
  }

  private var activityDate: Date {
    let storedUpdatedAt = project?.updatedAt ?? designSystem?.updatedAt ?? .distantPast
    guard let latestSessionDate = sessions.first?.lastAccessedAt else {
      return storedUpdatedAt
    }

    return max(storedUpdatedAt, latestSessionDate)
  }
}
