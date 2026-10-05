import EaselStudioCore
import Foundation
import Testing

@testable import EaselStudio

@MainActor
@Suite("StudioArtifactHandler")
struct StudioArtifactHandlerTests {
  private func makeLibrary(root: URL) -> (StudioLibrary, StudioPersistenceMock) {
    let persistence = StudioPersistenceMock()
    let library = StudioLibrary(
      persistence: persistence,
      documents: StudioDocumentWriter(rootURL: root.appendingPathComponent("studio", isDirectory: true)),
      index: StudioIndexStore(directoryURL: root.appendingPathComponent("studio-index", isDirectory: true))
    )
    return (library, persistence)
  }

  @Test("Routes by normalized project path and reports the stored artifact")
  func routesByProjectPath() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (library, _) = makeLibrary(root: root)

    var storedKeys: [String] = []
    let handler = StudioArtifactHandler(library: library) { _, key in
      storedKeys.append(key)
    }

    // Trailing slash must land in the same bucket as the clean path.
    let artifact = makeStudioCanvas(projectPath: "/tmp/project/")
    try await handler.handle(artifact)

    #expect(storedKeys == ["/tmp/project"])
    #expect(library.artifacts(forProjectKey: "/tmp/project").map(\.id) == [artifact.id])
  }

  @Test("An artifact with no project path is rejected, not stored")
  func missingProjectPathThrows() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (library, _) = makeLibrary(root: root)
    let handler = StudioArtifactHandler(library: library)

    await #expect(throws: StudioArtifactHandlingError.self) {
      try await handler.handle(makeStudioCanvas(projectPath: nil))
    }
    #expect(library.artifactsByProject.isEmpty)
  }

  @Test("A session id is provenance only — artifacts without one still store")
  func sessionIdOptional() async throws {
    let root = try temporaryStudioRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (library, persistence) = makeLibrary(root: root)
    let handler = StudioArtifactHandler(library: library)

    try await handler.handle(makeStudioCanvas(sessionId: nil, projectPath: "/tmp/project"))

    #expect(library.artifacts(forProjectKey: "/tmp/project").count == 1)
    let saved = try await persistence.getStudioArtifacts(forProjectPath: "/tmp/project")
    #expect(saved.first?.sessionId == "unknown")
  }
}
