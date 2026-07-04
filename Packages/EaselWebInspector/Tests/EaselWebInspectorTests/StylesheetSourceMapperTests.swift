import EaselKit
import Foundation
import Testing

@testable import EaselWebInspector

private struct MapperFixture {
  let root: URL

  static func create() throws -> MapperFixture {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("StylesheetSourceMapper-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return MapperFixture(root: URL(fileURLWithPath: root.path).standardizedFileURL.resolvingSymlinksInPath())
  }

  func cleanup() {
    try? FileManager.default.removeItem(at: root)
  }

  func write(_ relativePath: String, content: String) throws -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL.standardizedFileURL.resolvingSymlinksInPath().path
  }
}

private func makeLocator(
  href: String?,
  ruleIndexPath: [Int],
  selectorText: String,
  ownerNodeAttributes: [String: String] = [:],
  styleSheetIndex: Int = 0
) -> WebPreviewCSSRuleLocator {
  WebPreviewCSSRuleLocator(
    stylesheetHref: href,
    styleSheetIndex: styleSheetIndex,
    ruleIndexPath: ruleIndexPath,
    selectorText: selectorText,
    specificity: [0, 1, 0],
    ownerNodeAttributes: ownerNodeAttributes
  )
}

@Suite("StylesheetSourceMapper")
struct StylesheetSourceMapperTests {

  private let css = """
  .hero { color: red; }
  @media (min-width: 600px) {
    .cta { line-height: 26px; }
  }
  """

  @Test("file:// hrefs inside the project prove against the rule index path and selector")
  func fileHrefProves() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let cssPath = try fixture.write("styles/site.css", content: css)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: URL(fileURLWithPath: cssPath).absoluteString,
        ruleIndexPath: [1, 0],
        selectorText: ".cta"
      ),
      context: .directFile(servedFilePath: fixture.root.appendingPathComponent("index.html").path, projectPath: fixture.root.path)
    )

    let expectedSHA = StylesheetSourceMapper.sha256(of: css)
    #expect(result == .proven(filePath: cssPath, contentSHA256: expectedSHA, embeddedStyleBlockIndex: nil))
  }

  @Test("Dev-server hrefs map through the project path")
  func devServerHrefMapsThroughProjectPath() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let cssPath = try fixture.write("src/styles.css", content: css)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: "http://localhost:5173/src/styles.css",
        ruleIndexPath: [0],
        selectorText: ".hero"
      ),
      context: .devServer(baseURL: URL(string: "http://localhost:5173")!, projectPath: fixture.root.path)
    )

    guard case .proven(let filePath, _, _) = result else {
      Issue.record("Expected proven mapping, got \(result)")
      return
    }
    #expect(filePath == cssPath)
  }

  @Test("Vite data-vite-dev-id owner attribute maps directly to the source file")
  func viteDevIDMapsDirectly() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let cssPath = try fixture.write("src/App.css", content: css)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: nil,
        ruleIndexPath: [0],
        selectorText: ".hero",
        ownerNodeAttributes: ["data-vite-dev-id": cssPath]
      ),
      context: .devServer(baseURL: URL(string: "http://localhost:5173")!, projectPath: fixture.root.path)
    )

    guard case .proven(let filePath, _, _) = result else {
      Issue.record("Expected proven mapping, got \(result)")
      return
    }
    #expect(filePath == cssPath)
  }

  @Test("Candidates outside the project are rejected")
  func outOfProjectCandidatesRejected() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let outside = try MapperFixture.create()
    defer { outside.cleanup() }
    let outsideCSS = try outside.write("site.css", content: css)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: URL(fileURLWithPath: outsideCSS).absoluteString,
        ruleIndexPath: [0],
        selectorText: ".hero",
        ownerNodeAttributes: ["data-vite-dev-id": outsideCSS]
      ),
      context: .directFile(servedFilePath: fixture.root.appendingPathComponent("index.html").path, projectPath: fixture.root.path)
    )

    guard case .unproven = result else {
      Issue.record("Expected unproven mapping, got \(result)")
      return
    }
  }

  @Test("A rule index path that resolves to a different selector stays unproven")
  func indexPathSelectorMismatchIsUnproven() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let cssPath = try fixture.write("styles/site.css", content: css)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: URL(fileURLWithPath: cssPath).absoluteString,
        ruleIndexPath: [0],
        selectorText: ".cta"
      ),
      context: .directFile(servedFilePath: fixture.root.appendingPathComponent("index.html").path, projectPath: fixture.root.path)
    )

    guard case .unproven = result else {
      Issue.record("Expected unproven mapping, got \(result)")
      return
    }
  }

  @Test("Selector comparison tolerates whitespace and case differences")
  func selectorComparisonIsNormalized() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let cssPath = try fixture.write(
      "styles/site.css",
      content: "DIV.hero ,  .banner { color: red; }"
    )

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: URL(fileURLWithPath: cssPath).absoluteString,
        ruleIndexPath: [0],
        selectorText: "div.hero, .banner"
      ),
      context: .directFile(servedFilePath: fixture.root.appendingPathComponent("index.html").path, projectPath: fixture.root.path)
    )

    guard case .proven = result else {
      Issue.record("Expected proven mapping, got \(result)")
      return
    }
  }

  @Test("Dev-served inline <style> rules prove against the served HTML file")
  func devServerInlineStyleBlockProves() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    // Mirrors a single-file page: a cross-origin font <link> occupies
    // stylesheet index 0, the inline <style> block is index 1.
    let html = """
    <html><head>
    <link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />
    <style>
    .hero { color: #fff; }
    .hint button { font-size: 12px; }
    </style>
    </head><body><div class="hint"><button>Autofill</button></div></body></html>
    """
    let htmlPath = try fixture.write("index.html", content: html)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: nil,
        ruleIndexPath: [1],
        selectorText: ".hint button",
        styleSheetIndex: 1
      ),
      context: .devServer(
        baseURL: URL(string: "http://localhost:8123/")!,
        projectPath: fixture.root.path
      )
    )

    #expect(result == .proven(
      filePath: htmlPath,
      contentSHA256: StylesheetSourceMapper.sha256(of: html),
      embeddedStyleBlockIndex: 0
    ))
  }

  @Test("An inline-block locator that doesn't match the served file stays unproven")
  func inlineBlockMismatchStaysUnproven() async throws {
    let fixture = try MapperFixture.create()
    defer { fixture.cleanup() }
    let html = """
    <html><head><style>.other { color: red; }</style></head><body></body></html>
    """
    _ = try fixture.write("index.html", content: html)

    let mapper = StylesheetSourceMapper(fileService: DefaultProjectFileService())
    let result = await mapper.mapToProvenFile(
      ruleLocator: makeLocator(
        href: nil,
        ruleIndexPath: [0],
        selectorText: ".hint button",
        styleSheetIndex: 0
      ),
      context: .devServer(
        baseURL: URL(string: "http://localhost:8123/")!,
        projectPath: fixture.root.path
      )
    )

    guard case .unproven = result else {
      Issue.record("Expected unproven mapping, got \(result)")
      return
    }
  }

  @Test("Served document candidates cover directory and extensionless routes")
  func servedDocumentCandidates() {
    let root = "/project"
    #expect(StylesheetSourceMapper.servedDocumentCandidates(
      baseURL: URL(string: "http://localhost:3000/")!,
      projectPath: root
    ) == ["/project/index.html"])
    #expect(StylesheetSourceMapper.servedDocumentCandidates(
      baseURL: URL(string: "http://localhost:3000/pages/about.html")!,
      projectPath: root
    ) == ["/project/pages/about.html", "/project/pages/about.html/index.html"])
    #expect(StylesheetSourceMapper.servedDocumentCandidates(
      baseURL: URL(string: "http://localhost:3000/docs")!,
      projectPath: root
    ).contains("/project/docs.html"))
  }
}
