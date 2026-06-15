//
//  SlideDeckProjectContextImportKind.swift
//  EaselChat
//

import Foundation
import UniformTypeIdentifiers

enum SlideDeckProjectContextImportKind {
  case document
  case existingDeck

  var allowedContentTypes: [UTType] {
    switch self {
    case .document:
      return Self.unique([
        .pdf,
        .rtf,
        .text,
      ] + Self.contentTypes(forExtensions: [
        "doc",
        "docx",
        "md",
        "pages",
      ]))
    case .existingDeck:
      return Self.unique([
        .pdf,
      ] + Self.contentTypes(forExtensions: [
        "key",
        "ppt",
        "pptx",
      ]))
    }
  }

  var emptySelectionMessage: String {
    switch self {
    case .document:
      return "No document was selected."
    case .existingDeck:
      return "No presentation was selected."
    }
  }

  private static func contentTypes(forExtensions fileExtensions: [String]) -> [UTType] {
    fileExtensions.compactMap { fileExtension in
      UTType(filenameExtension: fileExtension)
    }
  }

  private static func unique(_ types: [UTType]) -> [UTType] {
    var seenIdentifiers = Set<String>()
    return types.filter { type in
      seenIdentifiers.insert(type.identifier).inserted
    }
  }
}
