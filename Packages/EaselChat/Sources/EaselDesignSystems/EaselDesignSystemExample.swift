//
//  EaselDesignSystemExample.swift
//  EaselChat
//

import Foundation

/// An example frame/screen extracted from a `.fig` source — useful for showing
/// product context. `previewPath` is populated once visual extraction runs.
public struct EaselDesignSystemExample: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let sourcePage: String?
  public let preview: EaselDesignSystemPreviewScene?

  public init(
    id: String,
    title: String,
    sourcePage: String?,
    preview: EaselDesignSystemPreviewScene? = nil
  ) {
    self.id = id
    self.title = title
    self.sourcePage = sourcePage
    self.preview = preview
  }
}
