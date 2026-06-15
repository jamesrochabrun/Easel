//
//  HighFidelityProjectContext.swift
//  EaselChat
//

import Foundation

struct HighFidelityProjectContext: Equatable, Sendable {
  var resourceURLs: [URL]
  var codebaseURLs: [URL]
  var textResources: [ProjectTextResource]

  init(
    resourceURLs: [URL] = [],
    codebaseURLs: [URL] = [],
    textResources: [ProjectTextResource] = []
  ) {
    self.resourceURLs = resourceURLs
    self.codebaseURLs = codebaseURLs
    self.textResources = textResources
  }

  static let empty = HighFidelityProjectContext()
}

struct ProjectTextResource: Equatable, Sendable {
  var fileName: String
  var contents: String
}
