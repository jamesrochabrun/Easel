//
//  PortAllocator.swift
//  EaselServerManager
//

import Foundation

struct PortAllocator: Sendable {

  static let basePort: UInt16 = 8080
  static let maxPort: UInt16 = 8999
  private static let persistenceKey = "easel.serverManager.portAssignments"

  /// Returns a persisted port for this directory, or assigns the lowest available one.
  static func assignPort(
    for workingDirectory: String,
    existingAssignments: [String: UInt16]
  ) -> UInt16 {
    if let existing = existingAssignments[workingDirectory] {
      return existing
    }

    let usedPorts = Set(existingAssignments.values)
    for port in basePort...maxPort {
      if !usedPorts.contains(port) {
        return port
      }
    }

    return basePort
  }

  static func loadAssignments() -> [String: UInt16] {
    guard let dict = UserDefaults.standard.dictionary(
      forKey: persistenceKey
    ) as? [String: Int] else {
      return [:]
    }
    return dict.mapValues { UInt16($0) }
  }

  static func saveAssignments(_ assignments: [String: UInt16]) {
    let dict = assignments.mapValues { Int($0) }
    UserDefaults.standard.set(dict, forKey: persistenceKey)
  }

  static func removeAssignment(
    for workingDirectory: String,
    from assignments: inout [String: UInt16]
  ) {
    assignments.removeValue(forKey: workingDirectory)
    saveAssignments(assignments)
  }
}
