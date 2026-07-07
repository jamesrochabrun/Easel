import Foundation

/// Confines file-tool paths to the project working directory.
///
/// Resolution: expand `~` → absolutize against `root` → standardize (removes
/// `..`) → resolve symlinks on the deepest existing ancestor (so not-yet-created
/// files can't dodge the check through a symlinked parent) → require the result
/// to stay under `root`. Writes additionally reject `writeDeniedSubpaths`.
///
/// Note for tests: construct the policy with an already-symlink-resolved root
/// (on macOS `/tmp` and `/var` are symlinks into `/private`); the initializer
/// resolves `root` for you.
public struct PathConfinementPolicy: Sendable {
  public let root: URL
  public var writeDeniedSubpaths: [String]

  public init(root: URL, writeDeniedSubpaths: [String] = ["resources/codebase-references"]) {
    self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    self.writeDeniedSubpaths = writeDeniedSubpaths
  }

  public enum Violation: Error, LocalizedError, Equatable {
    case outsideWorkspace(String)
    case writeDenied(String)

    public var errorDescription: String? {
      switch self {
      case .outsideWorkspace(let path):
        return "Path is outside the project workspace: \(path). Use a path inside the working directory."
      case .writeDenied(let path):
        return "Writing to \(path) is not allowed: this location is read-only reference material."
      }
    }
  }

  public func resolveForRead(_ path: String) throws -> URL {
    try resolveConfined(path)
  }

  public func resolveForWrite(_ path: String) throws -> URL {
    let url = try resolveConfined(path)
    let relative = relativePath(of: url)
    for denied in writeDeniedSubpaths {
      if relative == denied || relative.hasPrefix(denied + "/") {
        throw Violation.writeDenied(path)
      }
    }
    return url
  }

  // MARK: - Private

  private func resolveConfined(_ path: String) throws -> URL {
    let expanded = NSString(string: path).expandingTildeInPath
    let candidate: URL
    if expanded.hasPrefix("/") {
      candidate = URL(fileURLWithPath: expanded)
    } else {
      candidate = root.appendingPathComponent(expanded)
    }
    let resolved = resolvingDeepestExistingAncestor(candidate.standardizedFileURL)
    guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
      throw Violation.outsideWorkspace(path)
    }
    return resolved
  }

  /// Resolves symlinks even when the leaf doesn't exist yet: walks up to the
  /// deepest existing ancestor, resolves that, then re-appends the remainder.
  private func resolvingDeepestExistingAncestor(_ url: URL) -> URL {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      return url.resolvingSymlinksInPath()
    }
    var ancestor = url.deletingLastPathComponent()
    var tail = [url.lastPathComponent]
    while !fileManager.fileExists(atPath: ancestor.path), ancestor.path != "/" {
      tail.append(ancestor.lastPathComponent)
      ancestor = ancestor.deletingLastPathComponent()
    }
    var resolved = ancestor.resolvingSymlinksInPath()
    for component in tail.reversed() {
      resolved.appendPathComponent(component)
    }
    return resolved
  }

  private func relativePath(of url: URL) -> String {
    guard url.path.hasPrefix(root.path + "/") else { return "" }
    return String(url.path.dropFirst(root.path.count + 1))
  }
}
