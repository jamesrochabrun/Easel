import Foundation

/// Resolves which project a Studio artifact belongs to.
///
/// Artifacts are keyed by project, not by session: a canvas of button variants
/// is about *the project*, and Easel sessions come and go (a fresh CLI process
/// per turn). The app and the MCP server both normalize through here so the
/// same directory written three ways lands in one bucket — and so the index
/// file name they derive from the key is identical on both sides.
public enum StudioProjectKey {
  /// Expands `~`, resolves `..`, and drops a trailing slash.
  public static func normalized(_ path: String) -> String {
    let expanded = NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines))
      .expandingTildeInPath
    let standardized = (expanded as NSString).standardizingPath
    guard standardized.count > 1, standardized.hasSuffix("/") else {
      return standardized
    }
    return String(standardized.dropLast())
  }
}
