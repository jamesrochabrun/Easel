//
//  ProjectGroup.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

struct ProjectGroup: Identifiable {
  let id: String
  let displayName: String
  let project: EaselDesignProject?
  let workingDirectory: String?
  var sessions: [StoredSession]
  var isExpanded: Bool = true

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
    }

    let sessionLabel = sessions.count == 1 ? "1 session" : "\(sessions.count) sessions"
    parts.append(sessionLabel)
    return parts.joined(separator: " · ")
  }

  static func groups(
    projects: [EaselDesignProject],
    sessions: [StoredSession],
    previousExpansion: [String: Bool]
  ) -> [ProjectGroup] {
    let sessionsByDirectory = Dictionary(grouping: sessions) { session in
      session.workingDirectory ?? "ungrouped"
    }

    return projects.map { project in
      ProjectGroup(
        id: project.workingDirectory,
        displayName: project.name,
        project: project,
        workingDirectory: project.workingDirectory,
        sessions: sortedSessions(sessionsByDirectory[project.workingDirectory] ?? []),
        isExpanded: previousExpansion[project.workingDirectory] ?? true
      )
    }
  }

  private static func sortedSessions(_ sessions: [StoredSession]) -> [StoredSession] {
    sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }
}
