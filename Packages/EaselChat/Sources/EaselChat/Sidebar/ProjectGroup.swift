//
//  ProjectGroup.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

struct ProjectGroup: Identifiable {
  let id: String
  let displayName: String
  let workingDirectory: String?
  var sessions: [StoredSession]
  var isExpanded: Bool = true

  static func groupByProject(_ sessions: [StoredSession]) -> [ProjectGroup] {
    let grouped = Dictionary(grouping: sessions) { session -> String in
      session.workingDirectory ?? "ungrouped"
    }

    var projects = grouped.map { (directory, sessions) -> ProjectGroup in
      let displayName: String
      if directory == "ungrouped" {
        displayName = "Ungrouped"
      } else {
        displayName = URL(fileURLWithPath: directory).lastPathComponent
      }

      let sorted = sessions.sorted { $0.createdAt > $1.createdAt }

      return ProjectGroup(
        id: directory,
        displayName: displayName,
        workingDirectory: directory == "ungrouped" ? nil : directory,
        sessions: sorted
      )
    }

    // Sort projects by earliest session creation (stable order)
    projects.sort { lhs, rhs in
      let lhsDate = lhs.sessions.last?.createdAt ?? .distantPast
      let rhsDate = rhs.sessions.last?.createdAt ?? .distantPast
      return lhsDate < rhsDate
    }

    return projects
  }
}
