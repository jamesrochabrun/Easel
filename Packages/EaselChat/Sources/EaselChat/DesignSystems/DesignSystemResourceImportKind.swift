//
//  DesignSystemResourceImportKind.swift
//  EaselChat
//

import UniformTypeIdentifiers

enum DesignSystemResourceImportKind: String, Identifiable {
  case code
  case fig
  case assets

  var id: String { rawValue }

  var allowedContentTypes: [UTType] {
    switch self {
    case .code:
      return [.folder]
    case .fig:
      return [Self.figType, .data, .item]
    case .assets:
      return [.item]
    }
  }

  private static var figType: UTType {
    UTType(filenameExtension: "fig") ?? .data
  }
}
