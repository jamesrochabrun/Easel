import Canvas
import EaselKit
import Foundation
import Testing
@testable import EaselWebInspector

// MARK: - Mock file service

private actor MockProjectFileService: ProjectFileProviding {
  private(set) var files: [String: String]
  private(set) var writeCount = 0
  var failReads = false

  init(files: [String: String] = [:]) {
    self.files = files
  }

  func setFailReads(_ fail: Bool) {
    failReads = fail
  }

  func setFile(_ content: String, at path: String) {
    files[path] = content
  }

  func readFile(at path: String, projectPath: String) async throws -> String {
    guard !failReads, let content = files[path] else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return content
  }

  func writeFile(at path: String, content: String, projectPath: String) async throws {
    files[path] = content
    writeCount += 1
  }

  func listTextFiles(in projectPath: String, extensions: Set<String>) async -> [String] {
    Array(files.keys)
  }
}

// MARK: - Tests

@Suite("TweaksDefaultsWriteCoordinator")
struct TweaksDefaultsWriteCoordinatorTests {

  private static let filePath = "/project/Bluey Landing.dc.html"
  private static let projectPath = "/project"

  private static let sampleHTML = """
    <html><body>
    <script>
      dc_set_props({
        "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "value": 60 },
        "night": { "label": "Night", "type": "toggle", "value": false }
      });
    </script>
    </body></html>
    """

  private func makeCoordinator(
    service: MockProjectFileService
  ) -> TweaksDefaultsWriteCoordinator {
    TweaksDefaultsWriteCoordinator(
      projectPath: Self.projectPath,
      fileService: service,
      debounceInterval: .milliseconds(20),
      suppressionInterval: 1.5
    )
  }

  @Test func flushWritesLatestPendingValues() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    await coordinator.scheduleWrite(
      propName: "warmth", value: .number(70),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night"]
    )
    await coordinator.scheduleWrite(
      propName: "warmth", value: .number(85),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night"]
    )
    await coordinator.flush()

    let content = try #require(await service.files[Self.filePath])
    #expect(content.contains("\"value\": 85"))
    #expect(!content.contains("\"value\": 70"))
    // Coalesced: two schedules, one write.
    #expect(await service.writeCount == 1)
    #expect(await coordinator.isInSuppressionWindow())
  }

  @Test func debounceWritesWithoutExplicitFlush() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    await coordinator.scheduleWrite(
      propName: "night", value: .boolean(true),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night"]
    )
    try await Task.sleep(for: .milliseconds(200))

    let content = try #require(await service.files[Self.filePath])
    #expect(content.contains("\"type\": \"toggle\", \"value\": true }"))
  }

  @Test func skipsWhenPropNamesMismatch() async {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    await coordinator.scheduleWrite(
      propName: "warmth", value: .number(1),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night", "extra"]
    )
    await coordinator.flush()

    #expect(await service.writeCount == 0)
    #expect(await service.files[Self.filePath] == Self.sampleHTML)
    #expect(!(await coordinator.isInSuppressionWindow()))
  }

  @Test func skipsWhenFileUnreadable() async {
    let service = MockProjectFileService()
    let coordinator = makeCoordinator(service: service)

    await coordinator.scheduleWrite(
      propName: "warmth", value: .number(1),
      filePath: Self.filePath, liveSchemaNames: ["warmth"]
    )
    await coordinator.flush()

    #expect(await service.writeCount == 0)
  }

  @Test func flushWithoutPendingChangesIsNoOp() async {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)
    await coordinator.flush()
    #expect(await service.writeCount == 0)
  }

  @Test func multiplePropsWriteInOnePass() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    await coordinator.scheduleWrite(
      propName: "warmth", value: .number(30),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night"]
    )
    await coordinator.scheduleWrite(
      propName: "night", value: .boolean(true),
      filePath: Self.filePath, liveSchemaNames: ["warmth", "night"]
    )
    await coordinator.flush()

    #expect(await service.writeCount == 1)
    let content = try #require(await service.files[Self.filePath])
    let props = try TweakPropsSourceEditor.parseProps(fromSource: content)
    #expect(props.first(where: { $0.name == "warmth" })?.value == .number(30))
    #expect(props.first(where: { $0.name == "night" })?.value == .boolean(true))
  }
}

// MARK: - File-path resolution

@Suite("TweaksDefaultsWriteCoordinator path resolution")
struct TweaksFilePathResolutionTests {

  @Test func resolvesFileURLs() {
    let url = URL(fileURLWithPath: "/project/pages/Bluey Landing.dc.html")
    let path = TweaksDefaultsWriteCoordinator.resolveFilePath(previewURL: url, projectPath: "/project")
    #expect(path == "/project/pages/Bluey Landing.dc.html")
  }

  @Test func mapsDevServerRootToIndexHTML() {
    let url = URL(string: "http://localhost:3000/")!
    let path = TweaksDefaultsWriteCoordinator.resolveFilePath(previewURL: url, projectPath: "/project")
    #expect(path == "/project/index.html")
  }

  @Test func mapsDevServerPathsIntoProject() {
    let url = URL(string: "http://localhost:3000/about.html")!
    let path = TweaksDefaultsWriteCoordinator.resolveFilePath(previewURL: url, projectPath: "/project")
    #expect(path == "/project/about.html")

    let directory = URL(string: "http://localhost:3000/docs/")!
    let directoryPath = TweaksDefaultsWriteCoordinator.resolveFilePath(previewURL: directory, projectPath: "/project")
    #expect(directoryPath == "/project/docs/index.html")
  }

  @Test func rejectsUnsupportedSchemes() {
    let url = URL(string: "about:blank")!
    #expect(TweaksDefaultsWriteCoordinator.resolveFilePath(previewURL: url, projectPath: "/project") == nil)
  }
}
