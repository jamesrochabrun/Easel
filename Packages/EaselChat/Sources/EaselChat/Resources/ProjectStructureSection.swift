//
//  ProjectStructureSection.swift
//  EaselChat
//

import Foundation

public struct ProjectStructureSection: Identifiable, Equatable, Sendable {
  public let id: ProjectStructureRole
  public let role: ProjectStructureRole
  public let items: [ProjectStructureItem]

  public init(role: ProjectStructureRole, items: [ProjectStructureItem]) {
    self.id = role
    self.role = role
    self.items = items
  }

  var title: String {
    role.sectionTitle
  }
}
