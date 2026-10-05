import Foundation
import PackagePlugin

/// No-op stand-in for SwiftLintPlugin's build-tool plugin. See Package.swift
/// for why this override exists.
@main
struct SwiftLint: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    []
  }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLint: XcodeBuildToolPlugin {
  func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
    []
  }
}
#endif
