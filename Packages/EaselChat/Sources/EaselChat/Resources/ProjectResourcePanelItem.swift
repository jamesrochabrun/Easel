//
//  ProjectResourcePanelItem.swift
//  EaselChat
//

import Foundation

public enum ProjectResourcePanelItem: Identifiable, Equatable, Sendable {
  case resource(ProjectResource)
  case projectFile(ProjectStructureItem)

  public var id: String {
    switch self {
    case let .resource(resource):
      return "resource:\(resource.id)"
    case let .projectFile(item):
      return "project-file:\(item.id)"
    }
  }

  var fileName: String {
    switch self {
    case let .resource(resource):
      return resource.fileName
    case let .projectFile(item):
      return item.fileName
    }
  }

  var projectPath: String {
    switch self {
    case let .resource(resource):
      return resource.projectPath
    case let .projectFile(item):
      return item.projectPath
    }
  }

  var relativePath: String {
    switch self {
    case let .resource(resource):
      return resource.relativePath
    case let .projectFile(item):
      return item.relativePath
    }
  }

  var fileURL: URL {
    switch self {
    case let .resource(resource):
      return resource.fileURL
    case let .projectFile(item):
      return item.fileURL
    }
  }

  var kind: ProjectResource.Kind {
    switch self {
    case let .resource(resource):
      return resource.kind
    case let .projectFile(item):
      return item.kind
    }
  }

  var byteCount: Int64 {
    switch self {
    case let .resource(resource):
      return resource.byteCount
    case let .projectFile(item):
      return item.byteCount
    }
  }

  var modifiedAt: Date? {
    switch self {
    case let .resource(resource):
      return resource.modifiedAt
    case let .projectFile(item):
      return item.modifiedAt
    }
  }

  var sourceDisplayName: String {
    switch self {
    case .resource:
      return "Resource"
    case let .projectFile(item):
      return item.role.displayName
    }
  }
}
