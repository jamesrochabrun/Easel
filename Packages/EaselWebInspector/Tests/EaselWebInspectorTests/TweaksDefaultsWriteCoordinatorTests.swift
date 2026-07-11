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
  var failWrites = false

  init(files: [String: String] = [:]) {
    self.files = files
  }

  func setFailReads(_ fail: Bool) {
    failReads = fail
  }

  func setFailWrites(_ fail: Bool) {
    failWrites = fail
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
    guard !failWrites else {
      throw CocoaError(.fileWriteUnknown)
    }
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
      suppressionInterval: 1.5
    )
  }

  private func makeProps(
    warmth: TweakPropValue = .number(60),
    night: TweakPropValue = .boolean(false)
  ) -> [TweakProp] {
    [
      TweakProp(
        name: "warmth",
        label: "Warmth",
        type: .slider,
        minimum: 0,
        maximum: 100,
        value: warmth,
        defaultValue: .number(60)
      ),
      TweakProp(
        name: "night",
        label: "Night",
        type: .toggle,
        value: night,
        defaultValue: .boolean(false)
      ),
    ]
  }

  @Test func saveWritesChangedDefaults() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    try await coordinator.saveDefaults(
      props: makeProps(warmth: .number(85)),
      filePath: Self.filePath
    )

    let content = try #require(await service.files[Self.filePath])
    #expect(content.contains("\"value\": 85"))
    #expect(await service.writeCount == 1)
    #expect(await coordinator.isInSuppressionWindow())
  }

  @Test func unchangedValuesDoNotWrite() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    try await coordinator.saveDefaults(props: makeProps(), filePath: Self.filePath)

    #expect(await service.writeCount == 0)
    #expect(!(await coordinator.isInSuppressionWindow()))
  }

  @Test func rejectsWhenPropNamesMismatch() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)
    var props = makeProps(warmth: .number(1))
    props.append(TweakProp(name: "extra", label: "Extra", type: .toggle, value: .boolean(true)))

    do {
      try await coordinator.saveDefaults(props: props, filePath: Self.filePath)
      Issue.record("Expected a source-changed error")
    } catch let error as TweaksDefaultsWriteError {
      #expect(error == .sourceChanged)
    }

    #expect(await service.writeCount == 0)
    #expect(await service.files[Self.filePath] == Self.sampleHTML)
    #expect(!(await coordinator.isInSuppressionWindow()))
  }

  @Test func rejectsWhenDefaultsChangedOnDisk() async throws {
    let changedHTML = Self.sampleHTML.replacing("\"value\": 60", with: "\"value\": 70")
    let service = MockProjectFileService(files: [Self.filePath: changedHTML])
    let coordinator = makeCoordinator(service: service)

    do {
      try await coordinator.saveDefaults(
        props: makeProps(warmth: .number(85)),
        filePath: Self.filePath
      )
      Issue.record("Expected a source-changed error")
    } catch let error as TweaksDefaultsWriteError {
      #expect(error == .sourceChanged)
    }

    #expect(await service.writeCount == 0)
    #expect(await service.files[Self.filePath] == changedHTML)
  }

  @Test func reportsUnreadableFile() async throws {
    let service = MockProjectFileService()
    let coordinator = makeCoordinator(service: service)

    do {
      try await coordinator.saveDefaults(
        props: makeProps(warmth: .number(1)),
        filePath: Self.filePath
      )
      Issue.record("Expected a read error")
    } catch let error as TweaksDefaultsWriteError {
      #expect(error == .cannotReadFile)
    }

    #expect(await service.writeCount == 0)
  }

  @Test func rejectsComputedSourceDefaults() async throws {
    let computedHTML = Self.sampleHTML.replacing("\"value\": 60", with: "\"value\": initialWarmth")
    let service = MockProjectFileService(files: [Self.filePath: computedHTML])
    let coordinator = makeCoordinator(service: service)

    do {
      try await coordinator.saveDefaults(
        props: makeProps(warmth: .number(85)),
        filePath: Self.filePath
      )
      Issue.record("Expected an unsupported-value error")
    } catch let error as TweaksDefaultsWriteError {
      #expect(error == .unsupportedValue("warmth"))
    }

    #expect(await service.writeCount == 0)
  }

  @Test func multiplePropsWriteInOnePass() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    let coordinator = makeCoordinator(service: service)

    try await coordinator.saveDefaults(
      props: makeProps(warmth: .number(30), night: .boolean(true)),
      filePath: Self.filePath
    )

    #expect(await service.writeCount == 1)
    let content = try #require(await service.files[Self.filePath])
    let props = try TweakPropsSourceEditor.parseProps(fromSource: content)
    #expect(props.first(where: { $0.name == "warmth" })?.value == .number(30))
    #expect(props.first(where: { $0.name == "night" })?.value == .boolean(true))
  }

  @Test func writeFailureLeavesSourceUnchanged() async throws {
    let service = MockProjectFileService(files: [Self.filePath: Self.sampleHTML])
    await service.setFailWrites(true)
    let coordinator = makeCoordinator(service: service)

    do {
      try await coordinator.saveDefaults(
        props: makeProps(warmth: .number(85)),
        filePath: Self.filePath
      )
      Issue.record("Expected a write error")
    } catch let error as TweaksDefaultsWriteError {
      guard case .writeFailed = error else {
        Issue.record("Expected writeFailed, got \(error)")
        return
      }
    }

    #expect(await service.writeCount == 0)
    #expect(await service.files[Self.filePath] == Self.sampleHTML)
    #expect(!(await coordinator.isInSuppressionWindow()))
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
