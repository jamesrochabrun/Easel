//
//  EaselDesignSystemCreateRequest.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemCreateRequest: Equatable, Sendable {
  public let blurb: String
  public let sourceLinks: [String]
  public let codeSourceURLs: [URL]
  public let figFileURLs: [URL]
  public let figImportMode: EaselDesignSystemFigImportMode
  public let assetURLs: [URL]
  public let notes: String

  public init(
    blurb: String,
    sourceLinks: [String],
    codeSourceURLs: [URL],
    figFileURLs: [URL],
    figImportMode: EaselDesignSystemFigImportMode = .reference,
    assetURLs: [URL],
    notes: String
  ) {
    self.blurb = blurb
    self.sourceLinks = sourceLinks
    self.codeSourceURLs = codeSourceURLs
    self.figFileURLs = figFileURLs
    self.figImportMode = figImportMode
    self.assetURLs = assetURLs
    self.notes = notes
  }
}
