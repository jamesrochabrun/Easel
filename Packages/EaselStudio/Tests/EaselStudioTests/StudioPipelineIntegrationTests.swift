import EaselStudioCore
import Foundation
import Testing

@testable import EaselStudio

/// End-to-end: a queue record dropped by the MCP server becomes a document
/// served over localhost, exactly the path a live agent exercises.
@MainActor
@Suite("Studio pipeline integration")
struct StudioPipelineIntegrationTests {
  @Test("A queued record is drained, stored, indexed, and served over HTTP")
  func queuedRecordBecomesServedDocument() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let queue = StudioArtifactQueue(
      directoryURL: root.appendingPathComponent("studio-records", isDirectory: true)
    )
    let indexStore = StudioIndexStore(
      directoryURL: root.appendingPathComponent("studio-index", isDirectory: true)
    )
    let library = StudioLibrary(
      persistence: StudioSQLitePersistence(
        databaseURL: root.appendingPathComponent("studio.sqlite", isDirectory: false)
      ),
      documents: StudioDocumentWriter(rootURL: root.appendingPathComponent("studio", isDirectory: true)),
      index: indexStore
    )
    let handler = StudioArtifactHandler(library: library)
    let monitor = StudioArtifactMonitor(queue: queue, pollInterval: .milliseconds(20))

    // What the MCP server does in its own process.
    let artifact = makeStudioCanvas(projectPath: "/tmp/integration-project")
    try queue.enqueue(artifact)

    // What the app does at launch.
    await monitor.start { queued in
      try await handler.handle(queued.artifact)
    }
    defer { Task { await monitor.stop() } }

    // Drained into the library (and off the queue) within the poll budget.
    var waited = 0
    while library.artifacts(forProjectKey: "/tmp/integration-project").isEmpty, waited < 100 {
      try await Task.sleep(for: .milliseconds(20))
      waited += 1
    }
    let stored = library.artifacts(forProjectKey: "/tmp/integration-project")
    #expect(stored.map(\.id) == [artifact.id])
    #expect(try queue.pendingArtifacts().isEmpty)

    // Served over localhost with the canvas host page wrapping the variants.
    let servedURL = await library.servedURL(for: stored[0], projectKey: "/tmp/integration-project")
    let url = try #require(servedURL)
    #expect(url.host == "127.0.0.1")
    let (data, response) = try await URLSession.shared.data(from: url)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    let html = String(decoding: data, as: UTF8.self)
    #expect(html.contains("studio-artboard"))
    #expect(html.contains("data-variant=\"solid\""))
    #expect(html.contains("data-variant=\"ghost\""))

    // The agent-readable index points easel_get_artifact at the sidecar.
    var indexWaits = 0
    while indexStore.read(projectPath: "/tmp/integration-project") == nil, indexWaits < 100 {
      try await Task.sleep(for: .milliseconds(20))
      indexWaits += 1
    }
    let index = try #require(indexStore.read(projectPath: "/tmp/integration-project"))
    #expect(index.artifacts.map(\.id) == [artifact.id])
    let payloadPath = try #require(index.artifacts.first?.payloadPath)
    #expect(FileManager.default.fileExists(atPath: payloadPath))
  }
}
