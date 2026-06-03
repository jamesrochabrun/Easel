//
//  ProjectStructureItem.swift
//  EaselChat
//

import Foundation

public struct ProjectStructureItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let projectPath: String
  public let fileName: String
  public let relativePath: String
  public let fileURL: URL
  public let kind: ProjectResource.Kind
  public let role: ProjectStructureRole
  public let byteCount: Int64
  public let modifiedAt: Date?

  public init(
    projectPath: String,
    fileName: String,
    relativePath: String,
    fileURL: URL,
    kind: ProjectResource.Kind,
    role: ProjectStructureRole,
    byteCount: Int64,
    modifiedAt: Date?
  ) {
    self.id = "\(projectPath)/\(relativePath)"
    self.projectPath = projectPath
    self.fileName = fileName
    self.relativePath = relativePath
    self.fileURL = fileURL
    self.kind = kind
    self.role = role
    self.byteCount = byteCount
    self.modifiedAt = modifiedAt
  }
}
