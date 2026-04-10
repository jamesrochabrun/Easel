//
//  WebPreviewInspectorTab.swift
//  EaselWebInspector
//
//  Tabs available in the web preview inspector rail.
//

import Foundation

public enum WebPreviewInspectorTab: String, CaseIterable, Equatable, Sendable {
  case design
  case code
  case console

  public var title: String {
    switch self {
    case .design: "Design"
    case .code: "Code"
    case .console: "Console"
    }
  }
}
