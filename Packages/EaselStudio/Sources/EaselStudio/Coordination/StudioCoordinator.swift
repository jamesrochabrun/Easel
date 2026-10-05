import EaselStudioCore
import Foundation
import Observation

/// Composition root for Studio inside Easel, and the adaptive-surface brain.
///
/// Owns the library (SQLite persistence, document cache, static server, index),
/// the queue monitor, and the handler; publishes the signals the canvas pane
/// uses to flip between the live preview and the Designs surface:
/// - `lastArrivalToken` bumps when an artifact arrives → show Designs,
/// - `implementToken` bumps when an Implement request is sent → show Preview,
/// - `isUserEditing` suppresses auto-switching while the user is mid-edit.
@MainActor
@Observable
public final class StudioCoordinator {
  public let library: StudioLibrary

  /// Bumped whenever an artifact for `lastArrivalProjectKey` is filed or
  /// re-filed. Hosts observe it and switch the pane to the Designs surface.
  public private(set) var lastArrivalToken = 0
  public private(set) var lastArrivalProjectKey: String?

  /// Bumped when an Implement request leaves the Designs surface — the pane
  /// flips back to the live preview so the user watches the code land.
  public private(set) var implementToken = 0

  /// True while the user is mid-interaction on the Designs surface
  /// (inspecting, or holding unbaked edits). Hosts must not switch surfaces
  /// out from under them.
  public var isUserEditing = false

  @ObservationIgnored private let monitor: any StudioArtifactMonitorProtocol
  @ObservationIgnored private var handler: StudioArtifactHandler?
  @ObservationIgnored private var started = false

  public init(
    persistence: (any StudioPersisting)? = nil,
    documents: (any StudioDocumentWriting)? = nil,
    index: StudioIndexStore? = nil,
    monitor: (any StudioArtifactMonitorProtocol)? = nil
  ) {
    let supportDirectory = StudioSupportDirectory.baseURL()
    self.library = StudioLibrary(
      persistence: persistence ?? StudioSQLitePersistence(),
      documents: documents ?? StudioDocumentWriter(
        rootURL: supportDirectory.appendingPathComponent("studio", isDirectory: true)
      ),
      index: index ?? StudioIndexStore(
        directoryURL: supportDirectory.appendingPathComponent("studio-index", isDirectory: true)
      )
    )
    self.monitor = monitor ?? StudioArtifactMonitor(
      queue: StudioArtifactQueue(
        directoryURL: supportDirectory.appendingPathComponent("studio-records", isDirectory: true)
      )
    )
  }

  /// Reconciles storage, installs the bundled skill, and starts draining the
  /// MCP server's queue. Call once at app launch; idempotent.
  public func start() {
    guard !started else { return }
    started = true

    let handler = StudioArtifactHandler(library: library) { [weak self] _, projectKey in
      self?.noteArrival(projectKey: projectKey)
    }
    self.handler = handler

    StudioSkillInstaller.installBundledSkillForAllProvidersBestEffort()

    Task { @MainActor [library, monitor] in
      await library.reconcileStorage()
      await monitor.start { queued in
        try await handler.handle(queued.artifact)
      }
    }
  }

  public func stop() async {
    guard started else { return }
    started = false
    await monitor.stop()
    handler = nil
  }

  // MARK: - Surface signals

  public func hasArtifacts(forProjectPath projectPath: String?) -> Bool {
    guard let key = normalizedKey(projectPath) else { return false }
    return !library.artifacts(forProjectKey: key).isEmpty
  }

  /// Loads a project's persisted artifacts into memory (no-op when already
  /// loaded). Hosts call it when a project opens so `hasArtifacts` and the
  /// Designs surface see relaunch-persisted canvases.
  public func loadArtifacts(forProjectPath projectPath: String?) {
    guard let key = normalizedKey(projectPath) else { return }
    Task { @MainActor [library] in
      await library.load(projectKey: key, aliasPaths: [key])
    }
  }

  public func projectKey(forProjectPath projectPath: String?) -> String? {
    normalizedKey(projectPath)
  }

  /// The Designs surface calls this when an Implement request is sent.
  public func noteImplementSent() {
    implementToken &+= 1
  }

  func noteArrival(projectKey: String) {
    lastArrivalProjectKey = projectKey
    lastArrivalToken &+= 1
  }

  private func normalizedKey(_ projectPath: String?) -> String? {
    guard let projectPath, !projectPath.isEmpty else { return nil }
    return StudioProjectKey.normalized(projectPath)
  }
}
