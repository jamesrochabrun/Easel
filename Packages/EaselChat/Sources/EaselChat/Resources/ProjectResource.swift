//
//  ProjectResource.swift
//  EaselChat
//

import Foundation

public struct ProjectResource: Identifiable, Equatable, Sendable {
  public enum Kind: String, CaseIterable, Sendable {
    case image
    case video
    case audio
    case pdf
    case document
    case archive
    case other

    var displayName: String {
      switch self {
      case .image:
        return "Image"
      case .video:
        return "Video"
      case .audio:
        return "Audio"
      case .pdf:
        return "PDF"
      case .document:
        return "Document"
      case .archive:
        return "Archive"
      case .other:
        return "File"
      }
    }

    var systemImage: String {
      switch self {
      case .image:
        return "photo"
      case .video:
        return "film"
      case .audio:
        return "waveform"
      case .pdf:
        return "doc.richtext"
      case .document:
        return "doc.text"
      case .archive:
        return "archivebox"
      case .other:
        return "doc"
      }
    }
  }

  public static let resourcesDirectoryName = "resources"

  public let id: String
  public let projectPath: String
  public let fileName: String
  public let relativePath: String
  public let fileURL: URL
  public let kind: Kind
  public let byteCount: Int64
  public let modifiedAt: Date?

  public init(
    projectPath: String,
    fileName: String,
    relativePath: String,
    fileURL: URL,
    kind: Kind,
    byteCount: Int64,
    modifiedAt: Date?
  ) {
    self.id = "\(projectPath)/\(relativePath)"
    self.projectPath = projectPath
    self.fileName = fileName
    self.relativePath = relativePath
    self.fileURL = fileURL
    self.kind = kind
    self.byteCount = byteCount
    self.modifiedAt = modifiedAt
  }
}
