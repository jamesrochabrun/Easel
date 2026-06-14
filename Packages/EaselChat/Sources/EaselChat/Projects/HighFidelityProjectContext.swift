//
//  HighFidelityProjectContext.swift
//  EaselChat
//

import Foundation

struct HighFidelityProjectContext: Equatable, Sendable {
  var resourceURLs: [URL]
  var codebaseURLs: [URL]

  init(
    resourceURLs: [URL] = [],
    codebaseURLs: [URL] = []
  ) {
    self.resourceURLs = resourceURLs
    self.codebaseURLs = codebaseURLs
  }

  static let empty = HighFidelityProjectContext()
}
