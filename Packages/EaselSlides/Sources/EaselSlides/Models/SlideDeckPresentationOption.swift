//
//  SlideDeckPresentationOption.swift
//  EaselSlides
//

enum SlideDeckPresentationOption: String, CaseIterable, Equatable {
  case inThisTab
  case fullscreen
  case newTab

  var title: String {
    switch self {
    case .inThisTab:
      "In this tab"
    case .fullscreen:
      "Fullscreen"
    case .newTab:
      "New tab"
    }
  }

  var systemImage: String {
    switch self {
    case .inThisTab:
      "arrow.up.left.and.arrow.down.right"
    case .fullscreen:
      "play.rectangle.on.rectangle"
    case .newTab:
      "globe"
    }
  }
}
