//
//  DesignSystemResourceImportKind.swift
//  EaselChat
//

import UniformTypeIdentifiers

enum DesignSystemResourceImportKind: String, Identifiable {
  case code
  case fig
  case assets
  case designMarkdown

  var id: String { rawValue }

  var allowedContentTypes: [UTType] {
    switch self {
    case .code:
      return [.folder]
    case .fig:
      // Restrict to .fig only so other files can't be selected by accident.
      return [Self.figType]
    case .assets:
      return [.item]
    case .designMarkdown:
      return [Self.markdownType]
    }
  }

  private static var figType: UTType {
    // A dynamic UTType derived from the extension still filters the picker to
    // `.fig` files. Fall back to a restrictive type rather than `.data`/`.item`,
    // which would re-allow every file.
    UTType(filenameExtension: "fig") ?? .json
  }

  private static var markdownType: UTType {
    UTType(filenameExtension: "md") ?? .plainText
  }
}
