//
//  DesignLibraryItem.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import Foundation

public struct DesignLibraryItem: Identifiable, Sendable {
  public let id: String
  public let title: String
  public let kind: DesignLibraryItemKind
  public let workingDirectory: String
  public let updatedAt: Date
  public let latestSession: StoredSession?
  public let previewFile: DesignLibraryPreviewFile?
  public let project: EaselDesignProject?
  public let designSystem: EaselDesignSystemProfile?

  public init(
    id: String,
    title: String,
    kind: DesignLibraryItemKind,
    workingDirectory: String,
    updatedAt: Date,
    latestSession: StoredSession?,
    previewFile: DesignLibraryPreviewFile?,
    project: EaselDesignProject?,
    designSystem: EaselDesignSystemProfile?
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.workingDirectory = workingDirectory
    self.updatedAt = updatedAt
    self.latestSession = latestSession
    self.previewFile = previewFile
    self.project = project
    self.designSystem = designSystem
  }

  public var activityDate: Date {
    guard let latestSession else { return updatedAt }
    return max(updatedAt, latestSession.lastAccessedAt)
  }

  public var selection: DesignLibrarySelection? {
    if let project {
      return .project(project, latestSession: latestSession)
    }

    if let designSystem {
      return .designSystem(designSystem, latestSession: latestSession)
    }

    return nil
  }
}
