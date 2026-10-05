import EaselStudioCore
import Foundation

public protocol StudioArtifactMonitorProtocol: AnyObject, Sendable {
  func start(handler: @escaping @MainActor @Sendable (QueuedStudioArtifact) async throws -> Void) async
  func stop() async
}

/// Drains Studio artifacts the MCP server queued on disk into the app.
///
/// Polls the queue directory, hands each artifact to the app, and only deletes
/// the file once the app has taken it. A malformed record is renamed `.failed`
/// rather than retried forever.
public actor StudioArtifactMonitor: StudioArtifactMonitorProtocol {
  private let queue: StudioArtifactQueue
  private let pollInterval: Duration
  private var task: Task<Void, Never>?
  private var activeIds: Set<String> = []

  public init(
    queue: StudioArtifactQueue = StudioArtifactQueue(),
    pollInterval: Duration = .milliseconds(400)
  ) {
    self.queue = queue
    self.pollInterval = pollInterval
  }

  public func start(
    handler: @escaping @MainActor @Sendable (QueuedStudioArtifact) async throws -> Void
  ) async {
    guard task == nil else { return }

    task = Task { [queue, pollInterval] in
      while !Task.isCancelled {
        await self.processPending(queue: queue, handler: handler)
        try? await Task.sleep(for: pollInterval)
      }
    }
  }

  public func stop() async {
    task?.cancel()
    task = nil
    activeIds.removeAll()
  }

  private func processPending(
    queue: StudioArtifactQueue,
    handler: @escaping @MainActor @Sendable (QueuedStudioArtifact) async throws -> Void
  ) async {
    let pending: [QueuedStudioArtifact]
    do {
      pending = try queue.pendingArtifacts()
    } catch {
      StudioLog.logger.error("Failed to read Easel studio records: \(error.localizedDescription)")
      return
    }

    for queued in pending {
      guard activeIds.insert(queued.artifact.id).inserted else { continue }
      defer { activeIds.remove(queued.artifact.id) }

      do {
        try await handler(queued)
        try queue.remove(queued)
      } catch {
        StudioLog.logger.error("Failed to handle Easel studio record: \(error.localizedDescription)")
        do {
          try queue.markFailed(queued)
        } catch {
          StudioLog.logger.error("Failed to mark Easel studio record failed: \(error.localizedDescription)")
        }
      }
    }
  }

}
