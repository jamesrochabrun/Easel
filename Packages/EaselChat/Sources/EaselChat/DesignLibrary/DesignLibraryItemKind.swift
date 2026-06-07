//
//  DesignLibraryItemKind.swift
//  EaselChat
//

import Foundation

public enum DesignLibraryItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case prototype
  case slideDeck
  case designSystem

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .prototype:
      return "Prototype"
    case .slideDeck:
      return "Slide deck"
    case .designSystem:
      return "Design system"
    }
  }

  /// Title-cased plural used by the library filter chips.
  public var pluralDisplayName: String {
    switch self {
    case .prototype:
      return "Prototypes"
    case .slideDeck:
      return "Slide Decks"
    case .designSystem:
      return "Design Systems"
    }
  }

  var systemImage: String {
    switch self {
    case .prototype:
      return "rectangle.inset.filled"
    case .slideDeck:
      return "rectangle.on.rectangle"
    case .designSystem:
      return "square.grid.2x2"
    }
  }

  var badgeTint: DesignLibraryBadgeTint {
    switch self {
    case .prototype:
      return .neutral
    case .slideDeck:
      return .warm
    case .designSystem:
      return .soft
    }
  }

  var preparesSlideFirstPage: Bool {
    self == .slideDeck
  }

  init(projectKind: EaselProjectKind) {
    switch projectKind {
    case .prototype:
      self = .prototype
    case .slideDeck:
      self = .slideDeck
    }
  }
}
