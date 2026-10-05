import Foundation

/// Finds the bundled `EaselMCPServer` executable.
///
/// Release builds carry it in `Contents/Resources` (bundle_studio_server.sh);
/// debug runs from Xcode fall back to the package's own build products so the
/// Studio tools work without archiving.
enum StudioMCPServerLocator {
  static func serverPath() -> String? {
    if let bundlePath = Bundle.main.path(forResource: "EaselMCPServer", ofType: nil),
       FileManager.default.isExecutableFile(atPath: bundlePath)
    {
      return bundlePath
    }

    #if DEBUG
    // Walk from this source file to the repo's Packages directory.
    let packageBinary = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Studio/
      .deletingLastPathComponent() // EaselChat/
      .deletingLastPathComponent() // Sources/
      .deletingLastPathComponent() // EaselChat package root
      .deletingLastPathComponent() // Packages/
      .appendingPathComponent("EaselMCPServer/.build/debug/EaselMCPServer", isDirectory: false)
    if FileManager.default.isExecutableFile(atPath: packageBinary.path) {
      return packageBinary.path
    }
    #endif

    return nil
  }
}
