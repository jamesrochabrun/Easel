//
//  EaselDesignSystemProfile.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemProfile: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public let blurb: String
  public let notes: String
  public let sourceLinks: [String]
  public let workingDirectory: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    name: String,
    blurb: String,
    notes: String,
    sourceLinks: [String],
    workingDirectory: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.blurb = blurb
    self.notes = notes
    self.sourceLinks = sourceLinks
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
