//
//  WebInspectorDefaults.swift
//  EaselWebInspector
//
//  UserDefaults keys for web preview inspector feature flags.
//

import Foundation

public enum WebInspectorDefaults {
  /// Bool. When true (the default), Edit Mode style changes whose owning CSS
  /// rule and source file are proven write straight to disk; otherwise every
  /// edit batches to the session's agent.
  public static let webPreviewDirectCSSWriteEnabled = "easel.features.webPreviewDirectCSSWrite"

  /// Resolves the direct-CSS-write flag, defaulting to enabled when unset.
  public static func isDirectCSSWriteEnabled(defaults: UserDefaults = .standard) -> Bool {
    defaults.object(forKey: webPreviewDirectCSSWriteEnabled) as? Bool ?? true
  }
}
