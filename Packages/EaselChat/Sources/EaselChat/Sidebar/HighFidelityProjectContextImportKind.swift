//
//  HighFidelityProjectContextImportKind.swift
//  EaselChat
//

import Foundation
import UniformTypeIdentifiers

enum HighFidelityProjectContextImportKind {
  case screenshots
  case codebase
  case figma

  var allowedContentTypes: [UTType] {
    switch self {
    case .screenshots:
      return [.image]
    case .codebase:
      return [.folder]
    case .figma:
      return [Self.figType]
    }
  }

  var allowsMultipleSelection: Bool {
    switch self {
    case .screenshots:
      return true
    case .codebase, .figma:
      return false
    }
  }

  func context(from urls: [URL]) -> HighFidelityProjectContext {
    switch self {
    case .screenshots, .figma:
      return HighFidelityProjectContext(resourceURLs: urls)
    case .codebase:
      return HighFidelityProjectContext(codebaseURLs: Array(urls.prefix(1)))
    }
  }

  private static var figType: UTType {
    UTType(filenameExtension: "fig") ?? .json
  }
}
