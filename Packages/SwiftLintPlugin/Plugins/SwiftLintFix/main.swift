import Foundation
import PackagePlugin

/// No-op stand-in for SwiftLintPlugin's fix command. See Package.swift for
/// why this override exists.
@main
struct SwiftLintFix: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {}
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintFix: XcodeCommandPlugin {
  func performCommand(context: XcodePluginContext, arguments: [String]) throws {}
}
#endif
