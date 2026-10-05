import EaselStudioCore
import Foundation

@MainActor
public protocol StudioArtifactHandlingProtocol: AnyObject {
  func handle(_ artifact: StudioArtifact) async throws
}

enum StudioArtifactHandlingError: LocalizedError {
  case missingProjectPath

  var errorDescription: String? {
    switch self {
    case .missingProjectPath:
      return "The artifact did not name the project it belongs to."
    }
  }
}

/// Stores a filed Studio artifact into the library, keyed by project.
///
/// A deliberate divergence from AgentHub's session-routed handler: Easel runs
/// one active session per window and spawns a fresh CLI process per turn, so
/// the session id is provenance, not an address. The project path the MCP
/// server stamped into the artifact is the only routing key, and it is
/// required — an artifact with no project has nowhere to appear.
@MainActor
public final class StudioArtifactHandler: StudioArtifactHandlingProtocol {
  private let library: StudioLibrary
  private let onStored: (StudioArtifact, String) -> Void

  /// `onStored` fires after the library accepted the artifact, with the
  /// normalized project key — the coordinator uses it to surface arrivals.
  public init(
    library: StudioLibrary,
    onStored: @escaping (StudioArtifact, String) -> Void = { _, _ in }
  ) {
    self.library = library
    self.onStored = onStored
  }

  public func handle(_ artifact: StudioArtifact) async throws {
    guard let projectPath = artifact.sourceProjectPath, !projectPath.isEmpty else {
      throw StudioArtifactHandlingError.missingProjectPath
    }
    let key = StudioProjectKey.normalized(projectPath)

    // Merge what is already persisted first so a re-file right after launch
    // anchors on the stored artifact (revision continuity) instead of racing it.
    await library.load(projectKey: key, aliasPaths: [key])

    let stored = await library.store(
      artifact,
      projectKey: key,
      sessionId: artifact.sourceSessionId ?? "unknown",
      aliasPaths: [key]
    )
    onStored(stored, key)
  }
}
