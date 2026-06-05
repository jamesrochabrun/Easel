//
//  DesignLibraryPreviewFile.swift
//  EaselChat
//

import Foundation

public struct DesignLibraryPreviewFile: Equatable, Sendable {
  public let url: URL
  public let readAccessURL: URL
  public let modificationDate: Date?
  public let byteCount: Int?

  public init(
    url: URL,
    readAccessURL: URL,
    modificationDate: Date?,
    byteCount: Int?
  ) {
    self.url = url
    self.readAccessURL = readAccessURL
    self.modificationDate = modificationDate
    self.byteCount = byteCount
  }
}
