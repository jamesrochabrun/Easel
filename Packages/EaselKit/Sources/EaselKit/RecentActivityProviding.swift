//
//  RecentActivityProviding.swift
//  EaselKit
//

import Foundation

/// Provides recent file paths from user activity for source resolution heuristics.
public protocol RecentActivityProviding: Sendable {
  func recentFilePaths(projectPath: String) -> [String]
}
