import EaselStudioCore
import Foundation
import Testing

@testable import EaselStudio

@MainActor
@Suite("StudioCoordinator")
struct StudioCoordinatorTests {
  private final class MonitorStub: StudioArtifactMonitorProtocol, @unchecked Sendable {
    var handler: (@MainActor @Sendable (QueuedStudioArtifact) async throws -> Void)?
    func start(handler: @escaping @MainActor @Sendable (QueuedStudioArtifact) async throws -> Void) async {
      self.handler = handler
    }

    func stop() async { handler = nil }
  }

  private func makeCoordinator(root: URL) -> (StudioCoordinator, MonitorStub) {
    let monitor = MonitorStub()
    let coordinator = StudioCoordinator(
      persistence: StudioPersistenceMock(),
      documents: StudioDocumentWriter(rootURL: root.appendingPathComponent("studio", isDirectory: true)),
      index: StudioIndexStore(directoryURL: root.appendingPathComponent("studio-index", isDirectory: true)),
      monitor: monitor
    )
    return (coordinator, monitor)
  }

  @Test("An arriving artifact bumps the arrival token with its project key")
  func arrivalBumpsToken() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (coordinator, monitor) = makeCoordinator(root: root)
    coordinator.start()
    // start() launches monitor.start in a task; wait for the stub to receive it.
    var waits = 0
    while monitor.handler == nil, waits < 100 {
      try await Task.sleep(for: .milliseconds(10))
      waits += 1
    }
    let handler = try #require(monitor.handler)
    #expect(coordinator.lastArrivalToken == 0)

    let artifact = makeStudioCanvas(projectPath: "/tmp/project/")
    try await handler(QueuedStudioArtifact(artifact: artifact, fileURL: root))

    #expect(coordinator.lastArrivalToken == 1)
    #expect(coordinator.lastArrivalProjectKey == "/tmp/project")
    #expect(coordinator.hasArtifacts(forProjectPath: "/tmp/project/"))
    #expect(!coordinator.hasArtifacts(forProjectPath: "/tmp/other"))
    await coordinator.stop()
  }

  @Test("Implement bumps its own token and start() is idempotent")
  func implementTokenAndIdempotentStart() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (coordinator, _) = makeCoordinator(root: root)

    coordinator.start()
    coordinator.start()

    #expect(coordinator.implementToken == 0)
    coordinator.noteImplementSent()
    coordinator.noteImplementSent()
    #expect(coordinator.implementToken == 2)
    await coordinator.stop()
  }

  @Test("hasArtifacts is false for nil, empty, and unknown paths")
  func hasArtifactsEdgeCases() throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (coordinator, _) = makeCoordinator(root: root)

    #expect(!coordinator.hasArtifacts(forProjectPath: nil))
    #expect(!coordinator.hasArtifacts(forProjectPath: ""))
    #expect(coordinator.projectKey(forProjectPath: "/a/b/") == "/a/b")
  }
}
