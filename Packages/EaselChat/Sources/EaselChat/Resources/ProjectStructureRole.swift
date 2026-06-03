//
//  ProjectStructureRole.swift
//  EaselChat
//

import Foundation

public enum ProjectStructureRole: String, CaseIterable, Identifiable, Sendable {
  case pages
  case scripts
  case styles
  case data
  case assets
  case documents
  case other

  public var id: String { rawValue }

  var sectionTitle: String {
    switch self {
    case .pages:
      return "Pages"
    case .scripts:
      return "Scripts"
    case .styles:
      return "Styles"
    case .data:
      return "Data"
    case .assets:
      return "Assets"
    case .documents:
      return "Documents"
    case .other:
      return "Other Files"
    }
  }

  var displayName: String {
    switch self {
    case .pages:
      return "Page"
    case .scripts:
      return "Script"
    case .styles:
      return "Style"
    case .data:
      return "Data"
    case .assets:
      return "Asset"
    case .documents:
      return "Document"
    case .other:
      return "File"
    }
  }
}
