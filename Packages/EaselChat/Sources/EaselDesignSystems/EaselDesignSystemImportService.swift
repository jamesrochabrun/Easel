//
//  EaselDesignSystemImportService.swift
//  EaselChat
//

import CryptoKit
import Foundation

public protocol EaselDesignSystemImporting: Sendable {
  func importDesignSystemResources(_ request: EaselDesignSystemImportRequest) async -> EaselDesignSystemImportResult
}

public struct EaselDesignSystemImportRequest: Sendable {
  public let profile: EaselDesignSystemProfile
  public let directoryURL: URL
  public let figFileURLs: [URL]
  public let importMode: EaselDesignSystemFigImportMode

  public init(
    profile: EaselDesignSystemProfile,
    directoryURL: URL,
    figFileURLs: [URL],
    importMode: EaselDesignSystemFigImportMode
  ) {
    self.profile = profile
    self.directoryURL = directoryURL
    self.figFileURLs = figFileURLs
    self.importMode = importMode
  }
}

public struct EaselDesignSystemImportResult: Sendable {
  public let manifest: EaselDesignSystemManifest?
  public let catalog: EaselDesignSystemCatalog?
  /// Findings from linting the emitted `DESIGN.md`, surfaced to the UI.
  public let lintFindings: [DesignMarkdownLintFinding]

  public init(
    manifest: EaselDesignSystemManifest?,
    catalog: EaselDesignSystemCatalog?,
    lintFindings: [DesignMarkdownLintFinding] = []
  ) {
    self.manifest = manifest
    self.catalog = catalog
    self.lintFindings = lintFindings
  }
}

public actor LocalEaselDesignSystemImporter: EaselDesignSystemImporting {
  private let parser: any EaselFigFileParsing
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init() {
    self.init(parser: NodeEaselFigFileParser(), fileManager: .default)
  }

  init(
    parser: any EaselFigFileParsing,
    fileManager: FileManager = .default
  ) {
    self.parser = parser
    self.fileManager = fileManager

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func importDesignSystemResources(_ request: EaselDesignSystemImportRequest) async -> EaselDesignSystemImportResult {
    guard !request.figFileURLs.isEmpty else {
      return EaselDesignSystemImportResult(manifest: nil, catalog: nil)
    }

    do {
      let easelURL = request.directoryURL.appendingPathComponent(".easel", isDirectory: true)
      let importsURL = easelURL.appendingPathComponent("imports", isDirectory: true)
      try fileManager.createDirectory(at: importsURL, withIntermediateDirectories: true)

      let records = await importRecords(
        for: request,
        importsURL: importsURL
      )
      let manifest = EaselDesignSystemManifestNormalizer.makeManifest(
        profile: request.profile,
        importMode: request.importMode,
        records: records,
        generatedAt: Date()
      )
      let catalog = EaselDesignSystemManifestNormalizer.makeCatalog(
        profile: request.profile,
        manifest: manifest,
        records: records,
        directoryURL: request.directoryURL
      )

      try write(manifest, to: Self.manifestURL(for: request.directoryURL))
      try write(
        EaselDesignSystemCatalogHTMLRenderer.html(title: request.profile.name, blurb: request.profile.blurb),
        to: Self.indexURL(for: request.directoryURL)
      )

      // Make DESIGN.md the source of truth even for `.fig` imports: upgrade the
      // extracted catalog into a spec-compliant document, then re-derive
      // `catalog.json` from it while preserving Figma-only richness (preview
      // scenes, examples, assets, diagnostics).
      let document = DesignMarkdownEmitter.makeDocument(fromCatalog: catalog, profile: request.profile)
      let findings = DesignMarkdownLinter.lint(document)
      let derivedCatalog = DesignMarkdownCatalogMapper.makeCatalog(
        from: document,
        profile: request.profile,
        preservingFrom: catalog,
        generatedAt: catalog.generatedAt,
        lintWarnings: findings.filter { $0.severity != .error }.map { "\($0.rule): \($0.message)" }
      )
      try write(DesignMarkdownEmitter.emit(document), to: Self.designMarkdownURL(for: request.directoryURL))
      try write(derivedCatalog, to: Self.catalogURL(for: request.directoryURL))

      return EaselDesignSystemImportResult(manifest: manifest, catalog: derivedCatalog, lintFindings: findings)
    } catch {
      return EaselDesignSystemImportResult(manifest: nil, catalog: nil)
    }
  }

  private func importRecords(
    for request: EaselDesignSystemImportRequest,
    importsURL: URL
  ) async -> [EaselFigImportRecord] {
    var records: [EaselFigImportRecord] = []

    for figFileURL in request.figFileURLs {
      records.append(await importRecord(
        for: figFileURL,
        directoryURL: request.directoryURL,
        importMode: request.importMode,
        importsURL: importsURL
      ))
    }

    return records
  }

  private func importRecord(
    for figFileURL: URL,
    directoryURL: URL,
    importMode: EaselDesignSystemFigImportMode,
    importsURL: URL
  ) async -> EaselFigImportRecord {
    let fileName = figFileURL.lastPathComponent
    let relativePath = Self.relativePath(from: directoryURL, to: figFileURL)
    let parsedAt = Date()

    do {
      let sha256 = try Self.sha256Hex(for: figFileURL)

      guard importMode == .extractCatalog else {
        let source = EaselDesignSystemManifestSource(
          fileName: fileName,
          relativePath: relativePath,
          sha256: sha256,
          parserName: nil,
          parserVersion: nil,
          status: .skipped,
          parsedAt: parsedAt,
          nodeCount: 0,
          errorMessage: nil
        )
        return EaselFigImportRecord(source: source, document: nil)
      }

      // `v2` keeps the cache filename distinct from the pre-visual schema so
      // older caches (without geometry/asset data) are regenerated.
      let cacheURL = importsURL.appendingPathComponent("\(sha256).v2.fig-import.json")
      let assetsURL = directoryURL
        .appendingPathComponent(".easel", isDirectory: true)
        .appendingPathComponent("assets", isDirectory: true)
      let document: EaselParsedFigDocument
      if fileManager.fileExists(atPath: cacheURL.path) {
        let data = try Data(contentsOf: cacheURL)
        document = try decoder.decode(EaselParsedFigDocument.self, from: data)
      } else {
        document = try await parser.parseFigFile(at: figFileURL, assetsDirectory: assetsURL)
        let data = try encoder.encode(document)
        try data.write(to: cacheURL, options: .atomic)
      }

      let source = EaselDesignSystemManifestSource(
        fileName: fileName,
        relativePath: relativePath,
        sha256: sha256,
        parserName: document.parser.name,
        parserVersion: document.parser.version,
        status: .parsed,
        parsedAt: parsedAt,
        nodeCount: document.nodes.count,
        errorMessage: nil
      )
      return EaselFigImportRecord(source: source, document: document)
    } catch {
      let source = EaselDesignSystemManifestSource(
        fileName: fileName,
        relativePath: relativePath,
        sha256: (try? Self.sha256Hex(for: figFileURL)) ?? "",
        parserName: nil,
        parserVersion: nil,
        status: .failed,
        parsedAt: parsedAt,
        nodeCount: 0,
        errorMessage: error.localizedDescription
      )
      return EaselFigImportRecord(source: source, document: nil)
    }
  }

  private func write<T: Encodable>(_ value: T, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
  }

  private func write(_ value: String, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(value.utf8).write(to: url, options: .atomic)
  }

  private static func manifestURL(for directoryURL: URL) -> URL {
    directoryURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("design-system-manifest.json")
  }

  private static func catalogURL(for directoryURL: URL) -> URL {
    directoryURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("catalog.json")
  }

  private static func indexURL(for directoryURL: URL) -> URL {
    directoryURL.appendingPathComponent("index.html")
  }

  private static func designMarkdownURL(for directoryURL: URL) -> URL {
    directoryURL.appendingPathComponent("DESIGN.md")
  }

  private static func sha256Hex(for url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func relativePath(from baseURL: URL, to fileURL: URL) -> String {
    let basePath = baseURL.standardizedFileURL.path
    let filePath = fileURL.standardizedFileURL.path
    guard filePath.hasPrefix(basePath) else {
      return fileURL.lastPathComponent
    }

    let startIndex = filePath.index(filePath.startIndex, offsetBy: basePath.count)
    return String(filePath[startIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }
}

struct EaselFigImportRecord {
  let source: EaselDesignSystemManifestSource
  let document: EaselParsedFigDocument?
}

protocol EaselFigFileParsing: Sendable {
  func parseFigFile(at url: URL, assetsDirectory: URL?) async throws -> EaselParsedFigDocument
}

struct NodeEaselFigFileParser: EaselFigFileParsing {
  // Bumping this string forces the cached workspace (and its copy of
  // fig-importer.mjs) to be refreshed so script changes take effect.
  private let parserVersion = "0.4.0"

  init() {}

  func parseFigFile(at url: URL, assetsDirectory: URL?) async throws -> EaselParsedFigDocument {
    let workspaceURL = try await preparedWorkspaceURL()
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easel-fig-import-\(UUID().uuidString)")
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    var arguments = [
      workspaceURL.appendingPathComponent("fig-importer.mjs").path,
      url.path,
      outputURL.path,
    ]
    if let assetsDirectory {
      try? FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
      arguments.append(assetsDirectory.path)
    }

    let output = try await runProcess(
      executableName: "node",
      arguments: arguments,
      workingDirectory: workspaceURL
    )
    guard output.status == 0 else {
      throw EaselFigParserError.processFailed(output.errorText)
    }

    let data = try Data(contentsOf: outputURL)
    let decoder = JSONDecoder()
    return try decoder.decode(EaselParsedFigDocument.self, from: data)
  }

  private func preparedWorkspaceURL() async throws -> URL {
    let fileManager = FileManager.default
    let workspaceURL = try workspaceDirectoryURL()
    let markerURL = workspaceURL.appendingPathComponent(".easel-parser-version")
    let expectedMarker = "openfig-core@\(parserVersion)"
    let currentMarker = try? String(contentsOf: markerURL, encoding: .utf8)

    if currentMarker != expectedMarker, fileManager.fileExists(atPath: workspaceURL.path) {
      try fileManager.removeItem(at: workspaceURL)
    }

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    try copyResourceIfNeeded("package.json", to: workspaceURL)
    try copyResourceIfNeeded("fig-importer.mjs", to: workspaceURL)

    let dependencyURL = workspaceURL
      .appendingPathComponent("node_modules", isDirectory: true)
      .appendingPathComponent("openfig-core", isDirectory: true)

    if !fileManager.fileExists(atPath: dependencyURL.path) {
      let output = try await runProcess(
        executableName: "npm",
        arguments: ["install", "--omit=dev", "--no-audit", "--no-fund", "--prefer-offline"],
        workingDirectory: workspaceURL
      )
      guard output.status == 0 else {
        throw EaselFigParserError.processFailed(output.errorText)
      }
    }

    try expectedMarker.write(to: markerURL, atomically: true, encoding: .utf8)
    return workspaceURL
  }

  private func workspaceDirectoryURL() throws -> URL {
    let fileManager = FileManager.default
    let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? fileManager.temporaryDirectory
    return baseURL
      .appendingPathComponent("Easel", isDirectory: true)
      .appendingPathComponent("FigImporter", isDirectory: true)
      .appendingPathComponent("openfig-core-\(parserVersion)", isDirectory: true)
  }

  private func copyResourceIfNeeded(_ fileName: String, to workspaceURL: URL) throws {
    let fileManager = FileManager.default
    let destinationURL = workspaceURL.appendingPathComponent(fileName)
    guard !fileManager.fileExists(atPath: destinationURL.path) else { return }

    let sourceURL = try bundledImporterResourceURL(for: fileName)
    try fileManager.copyItem(at: sourceURL, to: destinationURL)
  }

  private func bundledImporterResourceURL(for fileName: String) throws -> URL {
    if let resourceDirectoryURL = Bundle.module.url(forResource: "FigImporter", withExtension: nil) {
      let sourceURL = resourceDirectoryURL.appendingPathComponent(fileName)
      if FileManager.default.fileExists(atPath: sourceURL.path) {
        return sourceURL
      }
    }

    let fileURL = URL(fileURLWithPath: fileName)
    let baseName = fileURL.deletingPathExtension().lastPathComponent
    let pathExtension = fileURL.pathExtension
    if let flattenedURL = Bundle.module.url(
      forResource: baseName,
      withExtension: pathExtension.isEmpty ? nil : pathExtension
    ) {
      return flattenedURL
    }

    throw EaselFigParserError.missingBundledImporter
  }

  private func runProcess(
    executableName: String,
    arguments: [String],
    workingDirectory: URL
  ) async throws -> EaselProcessOutput {
    let executableURL = try Self.resolvedExecutableURL(named: executableName)
    return try await runProcess(
      executableURL: executableURL,
      arguments: arguments,
      workingDirectory: workingDirectory
    )
  }

  static func resolvedExecutableURL(
    named executableName: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) throws -> URL {
    for directoryURL in executableSearchDirectories(
      environment: environment,
      homeDirectory: homeDirectory,
      fileManager: fileManager
    ) {
      let candidateURL = directoryURL.appendingPathComponent(executableName)
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory),
            !isDirectory.boolValue,
            fileManager.isExecutableFile(atPath: candidateURL.path) else {
        continue
      }
      return candidateURL.standardizedFileURL
    }

    throw EaselFigParserError.missingExecutable(executableName)
  }

  static func executableSearchDirectories(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) -> [URL] {
    var directories: [URL] = []

    if let path = environment["PATH"] {
      directories.append(contentsOf: path.split(separator: ":").map { pathComponent in
        URL(fileURLWithPath: String(pathComponent), isDirectory: true)
      })
    }

    directories.append(contentsOf: [
      URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
      URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
      URL(fileURLWithPath: "/usr/bin", isDirectory: true),
      URL(fileURLWithPath: "/bin", isDirectory: true),
      URL(fileURLWithPath: "/usr/sbin", isDirectory: true),
      URL(fileURLWithPath: "/sbin", isDirectory: true),
      homeDirectory.appendingPathComponent(".volta/bin", isDirectory: true),
      homeDirectory.appendingPathComponent(".asdf/shims", isDirectory: true)
    ])

    let nvmVersionsURL = homeDirectory
      .appendingPathComponent(".nvm", isDirectory: true)
      .appendingPathComponent("versions", isDirectory: true)
      .appendingPathComponent("node", isDirectory: true)
    if let versionNames = try? fileManager.contentsOfDirectory(atPath: nvmVersionsURL.path) {
      directories.append(contentsOf: versionNames.sorted(by: >).map { versionName in
        nvmVersionsURL
          .appendingPathComponent(versionName, isDirectory: true)
          .appendingPathComponent("bin", isDirectory: true)
      })
    }

    var seenPaths: Set<String> = []
    return directories.filter { directoryURL in
      let path = directoryURL.standardizedFileURL.path
      guard !path.isEmpty, !seenPaths.contains(path) else { return false }
      seenPaths.insert(path)
      return true
    }
  }

  private static func processEnvironment(
    for executableURL: URL,
    baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String: String] {
    var environment = baseEnvironment
    let executableDirectoryPath = executableURL.deletingLastPathComponent().path
    let currentPath = baseEnvironment["PATH"] ?? ""
    let pathParts = ([executableDirectoryPath] + currentPath.split(separator: ":").map(String.init))
      .filter { !$0.isEmpty }

    var seenPaths: Set<String> = []
    environment["PATH"] = pathParts.filter { path in
      guard !seenPaths.contains(path) else { return false }
      seenPaths.insert(path)
      return true
    }.joined(separator: ":")

    return environment
  }

  private func runProcess(
    executableURL: URL,
    arguments: [String],
    workingDirectory: URL
  ) async throws -> EaselProcessOutput {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      let outputPipe = Pipe()
      let errorPipe = Pipe()

      process.executableURL = executableURL
      process.arguments = arguments
      process.environment = Self.processEnvironment(for: executableURL)
      process.currentDirectoryURL = workingDirectory
      process.standardOutput = outputPipe
      process.standardError = errorPipe
      process.terminationHandler = { terminatedProcess in
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        continuation.resume(returning: EaselProcessOutput(
          status: terminatedProcess.terminationStatus,
          outputData: outputData,
          errorData: errorData
        ))
      }

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

struct EaselProcessOutput {
  let status: Int32
  let outputData: Data
  let errorData: Data

  var errorText: String {
    let text = String(data: errorData, encoding: .utf8)
      ?? String(data: outputData, encoding: .utf8)
      ?? "The .fig parser failed."
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

enum EaselFigParserError: LocalizedError {
  case missingBundledImporter
  case missingExecutable(String)
  case processFailed(String)

  var errorDescription: String? {
    switch self {
    case .missingBundledImporter:
      return "The bundled .fig importer could not be found."
    case let .missingExecutable(executableName):
      return "The .fig parser needs \(executableName), but it was not found on this Mac."
    case let .processFailed(message):
      return message.isEmpty ? "The .fig parser failed." : message
    }
  }
}

struct EaselParsedFigDocument: Codable, Equatable, Sendable {
  let parser: EaselParsedFigParser
  let document: EaselParsedFigDocumentInfo
  let nodes: [EaselParsedFigNode]
}

struct EaselParsedFigParser: Codable, Equatable, Sendable {
  let name: String
  let version: String
}

struct EaselParsedFigDocumentInfo: Codable, Equatable, Sendable {
  let nodeCount: Int
  let pageCount: Int
  let thumbnailPath: String?
  let imageAssets: [EaselParsedFigImageAsset]

  init(
    nodeCount: Int,
    pageCount: Int,
    thumbnailPath: String? = nil,
    imageAssets: [EaselParsedFigImageAsset] = []
  ) {
    self.nodeCount = nodeCount
    self.pageCount = pageCount
    self.thumbnailPath = thumbnailPath
    self.imageAssets = imageAssets
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    nodeCount = try container.decode(Int.self, forKey: .nodeCount)
    pageCount = try container.decode(Int.self, forKey: .pageCount)
    thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
    imageAssets = try container.decodeIfPresent([EaselParsedFigImageAsset].self, forKey: .imageAssets) ?? []
  }
}

struct EaselParsedFigImageAsset: Codable, Equatable, Sendable {
  let name: String
  let path: String
}

struct EaselParsedFigNode: Codable, Equatable, Sendable {
  let id: String
  let type: String
  let name: String
  let parentID: String?
  let pageName: String?
  let depth: Int
  let x: Double?
  let y: Double?
  let width: Double?
  let height: Double?
  let childCount: Int
  let opacity: Double?
  let fillColors: [String]
  let strokeColors: [String]
  let strokeWeight: Double?
  let fontFamily: String?
  let fontStyle: String?
  let fontSize: Double?
  let textAlign: String?
  let text: String?
  let cornerRadius: Double?
  let effectTypes: [String]
  let imageRef: String?
  let vectorPath: String?

  init(
    id: String,
    type: String,
    name: String,
    parentID: String?,
    pageName: String?,
    depth: Int,
    x: Double? = nil,
    y: Double? = nil,
    width: Double?,
    height: Double?,
    childCount: Int,
    opacity: Double? = nil,
    fillColors: [String],
    strokeColors: [String],
    strokeWeight: Double? = nil,
    fontFamily: String?,
    fontStyle: String?,
    fontSize: Double?,
    textAlign: String? = nil,
    text: String?,
    cornerRadius: Double?,
    effectTypes: [String],
    imageRef: String? = nil,
    vectorPath: String? = nil
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.parentID = parentID
    self.pageName = pageName
    self.depth = depth
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.childCount = childCount
    self.opacity = opacity
    self.fillColors = fillColors
    self.strokeColors = strokeColors
    self.strokeWeight = strokeWeight
    self.fontFamily = fontFamily
    self.fontStyle = fontStyle
    self.fontSize = fontSize
    self.textAlign = textAlign
    self.text = text
    self.cornerRadius = cornerRadius
    self.effectTypes = effectTypes
    self.imageRef = imageRef
    self.vectorPath = vectorPath
  }
}

enum EaselDesignSystemManifestNormalizer {
  static func makeManifest(
    profile: EaselDesignSystemProfile,
    importMode: EaselDesignSystemFigImportMode,
    records: [EaselFigImportRecord],
    generatedAt: Date
  ) -> EaselDesignSystemManifest {
    let parsedRecords = records.filter { $0.document != nil }
    let tokens = importMode == .extractCatalog
      ? makeTokenSet(from: parsedRecords)
      : .empty
    let components = importMode == .extractCatalog
      ? makeComponents(from: parsedRecords)
      : []
    let references = makeReferences(from: parsedRecords, importMode: importMode)
    let summary = makeSummary(
      importMode: importMode,
      parsedCount: parsedRecords.count,
      sourceCount: records.count,
      colorCount: tokens.colors.count,
      typographyCount: tokens.typography.count,
      componentCount: components.count,
      referenceCount: references.count
    )

    return EaselDesignSystemManifest(
      name: profile.name,
      summary: summary,
      generatedAt: generatedAt,
      importMode: importMode,
      sources: records.map(\.source),
      tokens: tokens,
      components: components,
      references: references
    )
  }

  static func makeCatalog(
    profile: EaselDesignSystemProfile,
    manifest: EaselDesignSystemManifest,
    records: [EaselFigImportRecord] = [],
    directoryURL: URL? = nil
  ) -> EaselDesignSystemCatalog {
    let diagnostics = makeSourceDiagnostics(from: manifest)
    let isExtract = manifest.importMode == .extractCatalog
    // The parser lists every referenced image fill, but only a subset are
    // actually written to `.easel/assets/`. Resolve the real files once so the
    // catalog never points at art that was never exported.
    let existingAssets = directoryURL.map(existingAssetPaths(in:)) ?? []

    guard isExtract else {
      // Attach-only mode keeps the .fig with the design system without parsing
      // it into tokens/components.
      return EaselDesignSystemCatalog(
        name: profile.name,
        summary: manifest.summary,
        generatedAt: manifest.generatedAt,
        componentGroups: [],
        title: "\(profile.name) — local design",
        isReference: true,
        disclaimer: EaselDesignSystemCatalog.referenceFigDisclaimer,
        sourceDiagnostics: diagnostics
      )
    }

    let tokens = manifest.tokens
    let hasTokens = tokens.colors.count + tokens.typography.count
      + tokens.spacing.count + tokens.radii.count + tokens.effects.count > 0

    let sceneIndexes = makeSceneIndexes(from: records)

    let families = manifest.components.map { component in
      EaselDesignSystemComponentFamily(
        id: component.id,
        title: component.title,
        category: component.category,
        summary: component.summary,
        sourcePage: component.sourcePageName,
        variantCount: component.variantCount,
        variantProperties: component.variantProperties,
        preview: makeScene(
          forNodeID: component.sourceNodeID,
          fileName: component.sourceFileName,
          indexes: sceneIndexes,
          existingAssets: existingAssets
        ),
        confidence: component.confidence
      )
    }

    // Examples are only surfaced when their schematic preview reads like a
    // screen/frame thumbnail. Box-less pages resolve to a framed child (see
    // `renderRoot`), but documentation boards still produce oversized or
    // extreme-aspect scenes that shrink to an illegible sliver in the gallery —
    // drop those so the section shows real screens or hides itself entirely.
    let examples = manifest.references.compactMap { reference -> EaselDesignSystemExample? in
      guard let preview = makeScene(
        forNodeID: reference.sourceNodeID,
        fileName: reference.sourceFileName,
        indexes: sceneIndexes,
        existingAssets: existingAssets
      ), isPresentableExampleScene(preview) else {
        return nil
      }
      return EaselDesignSystemExample(
        id: reference.id,
        title: reference.title,
        sourcePage: reference.sourcePageName,
        preview: preview
      )
    }
    .prefix(12)

    let assets = makeAssets(from: records, existingAssets: existingAssets)
    let heroThumbnailPath = records
      .compactMap { $0.document?.document.thumbnailPath }
      .first
      .map { assetsRelativePrefix + $0 }
      .flatMap { existingAssets.isEmpty || existingAssets.contains($0) ? $0 : nil }

    return EaselDesignSystemCatalog(
      name: profile.name,
      summary: manifest.summary,
      generatedAt: manifest.generatedAt,
      componentGroups: makeComponentGroups(from: manifest.components),
      title: "\(profile.name) — local design",
      isReference: true,
      disclaimer: EaselDesignSystemCatalog.extractedFigDisclaimer,
      tokens: hasTokens ? tokens : nil,
      componentFamilies: families.isEmpty ? nil : families,
      examples: examples.isEmpty ? nil : Array(examples),
      assets: assets.isEmpty ? nil : assets,
      heroThumbnailPath: heroThumbnailPath,
      sourceDiagnostics: diagnostics
    )
  }

  // Paths emitted by the parser are relative to `.easel/assets`; the catalog
  // stores them relative to the design system root so they resolve in both the
  // served `index.html` and the native browser.
  static let assetsRelativePrefix = ".easel/assets/"

  private struct FigSceneIndex {
    let nodesByID: [String: EaselParsedFigNode]
    let childrenByParent: [String: [EaselParsedFigNode]]
  }

  private static func makeSceneIndexes(
    from records: [EaselFigImportRecord]
  ) -> [String: FigSceneIndex] {
    var indexes: [String: FigSceneIndex] = [:]
    for record in records {
      guard let document = record.document else { continue }
      var nodesByID: [String: EaselParsedFigNode] = [:]
      var childrenByParent: [String: [EaselParsedFigNode]] = [:]
      for node in document.nodes {
        nodesByID[node.id] = node
        if let parentID = node.parentID {
          childrenByParent[parentID, default: []].append(node)
        }
      }
      indexes[record.source.fileName] = FigSceneIndex(
        nodesByID: nodesByID,
        childrenByParent: childrenByParent
      )
    }
    return indexes
  }

  private static func makeAssets(
    from records: [EaselFigImportRecord],
    existingAssets: Set<String>
  ) -> [EaselDesignSystemAsset] {
    // When we know which files were actually written, only surface those. (An
    // empty set means we couldn't resolve the folder — keep the old behavior.)
    func exists(_ path: String) -> Bool { existingAssets.isEmpty || existingAssets.contains(path) }
    var assets: [EaselDesignSystemAsset] = []
    var seen: Set<String> = []
    for record in records {
      guard let document = record.document else { continue }
      if let thumbnailPath = document.document.thumbnailPath {
        let relativePath = assetsRelativePrefix + thumbnailPath
        if exists(relativePath), seen.insert(relativePath).inserted {
          assets.append(EaselDesignSystemAsset(
            id: "asset-thumbnail-\(slug(for: record.source.fileName))",
            name: "Document thumbnail",
            relativePath: relativePath,
            kind: "thumbnail"
          ))
        }
      }
      for image in document.document.imageAssets {
        if assets.count >= 60 { break }
        let relativePath = assetsRelativePrefix + image.path
        guard exists(relativePath), seen.insert(relativePath).inserted else { continue }
        assets.append(EaselDesignSystemAsset(
          id: "asset-\(slug(for: image.path))",
          name: image.name,
          relativePath: relativePath,
          kind: "image"
        ))
      }
      if assets.count >= 60 { break }
    }
    return Array(assets.prefix(60))
  }

  /// Relative paths (from the design system root) of every asset file actually
  /// written under `.easel/assets/`. Used to drop catalog references to image
  /// fills the parser listed but never exported.
  private static func existingAssetPaths(in directoryURL: URL) -> Set<String> {
    let assetsURL = directoryURL.appendingPathComponent(assetsRelativePrefix, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
      at: assetsURL,
      includingPropertiesForKeys: [.isRegularFileKey]
    ) else {
      return []
    }
    let basePath = directoryURL.standardizedFileURL.path
    var paths: Set<String> = []
    for case let url as URL in enumerator {
      let filePath = url.standardizedFileURL.path
      guard filePath.hasPrefix(basePath + "/") else { continue }
      paths.insert(String(filePath.dropFirst(basePath.count + 1)))
    }
    return paths
  }

  /// Builds a capped schematic preview scene for a representative node by walking
  /// its descendant subtree and emitting positioned rect/text/image/path layers.
  private static func makeScene(
    forNodeID nodeID: String,
    fileName: String,
    indexes: [String: FigSceneIndex],
    existingAssets: Set<String>
  ) -> EaselDesignSystemPreviewScene? {
    guard let index = indexes[fileName],
          let requestedNode = index.nodesByID[nodeID],
          let root = renderRoot(for: requestedNode, in: index),
          let width = root.width, let height = root.height,
          width > 1, height > 1, width <= 8000, height <= 8000 else {
      return nil
    }

    let maxLayers = 60
    let maxDepth = 6
    var layers: [EaselDesignSystemPreviewLayer] = []

    func appendLayer(for node: EaselParsedFigNode, x: Double, y: Double, w: Double, h: Double) {
      if let imageRef = node.imageRef,
         existingAssets.isEmpty || existingAssets.contains(assetsRelativePrefix + imageRef) {
        layers.append(EaselDesignSystemPreviewLayer(
          id: node.id, kind: .image, x: x, y: y, width: w, height: h,
          opacity: node.opacity, imagePath: assetsRelativePrefix + imageRef
        ))
      } else if let path = node.vectorPath {
        layers.append(EaselDesignSystemPreviewLayer(
          id: node.id, kind: .path, x: x, y: y, width: w, height: h,
          fill: node.fillColors.first ?? "#8D867D", opacity: node.opacity, path: path
        ))
      } else if let text = node.text, !text.isEmpty {
        layers.append(EaselDesignSystemPreviewLayer(
          id: node.id, kind: .text, x: x, y: y, width: w, height: h,
          opacity: node.opacity, text: text, fontSize: node.fontSize,
          fontWeight: node.fontStyle, textColor: node.fillColors.first, align: node.textAlign
        ))
      } else if node.fillColors.first != nil || node.strokeColors.first != nil {
        layers.append(EaselDesignSystemPreviewLayer(
          id: node.id, kind: .rect, x: x, y: y, width: w, height: h,
          cornerRadius: node.cornerRadius, fill: node.fillColors.first,
          stroke: node.strokeColors.first, strokeWidth: node.strokeWeight, opacity: node.opacity
        ))
      }
    }

    func visit(_ node: EaselParsedFigNode, originX: Double, originY: Double, depth: Int) {
      guard depth <= maxDepth, layers.count < maxLayers else { return }
      for child in index.childrenByParent[node.id] ?? [] {
        if layers.count >= maxLayers { break }
        let cx = originX + (child.x ?? 0)
        let cy = originY + (child.y ?? 0)
        let cw = child.width ?? 0
        let ch = child.height ?? 0
        // Skip fully out-of-frame subtrees to keep the scene tight.
        if cx >= width || cy >= height || cx + cw <= 0 || cy + ch <= 0 {
          continue
        }
        if cw > 0, ch > 0 {
          appendLayer(for: child, x: cx, y: cy, w: cw, h: ch)
        }
        visit(child, originX: cx, originY: cy, depth: depth + 1)
      }
    }

    if let background = root.fillColors.first {
      layers.append(EaselDesignSystemPreviewLayer(
        id: "\(root.id)-bg", kind: .rect, x: 0, y: 0, width: width, height: height,
        cornerRadius: root.cornerRadius, fill: background
      ))
    }
    visit(root, originX: 0, originY: 0, depth: 0)

    guard !layers.isEmpty else { return nil }
    return EaselDesignSystemPreviewScene(
      width: width,
      height: height,
      background: root.fillColors.first,
      layers: layers
    )
  }

  /// Resolves the node to actually render for a preview scene.
  ///
  /// Most representative nodes (`COMPONENT`/`FRAME`) carry their own bounding
  /// box, so they render as-is. But page-level `CANVAS` nodes — and any
  /// container Figma never gives a frame box — have no width/height. Files
  /// organized as one page per component (e.g. an "Accordion" page, an "Alert"
  /// page) surface those pages as examples, and without this resolution every
  /// one would fail `makeScene`'s dimension guard and show an empty placeholder.
  /// In that case we descend a shallow window of descendants and render the
  /// largest framed node as a representative single-frame preview.
  private static func renderRoot(
    for node: EaselParsedFigNode,
    in index: FigSceneIndex
  ) -> EaselParsedFigNode? {
    func hasUsableBox(_ candidate: EaselParsedFigNode) -> Bool {
      guard let width = candidate.width, let height = candidate.height else { return false }
      return width > 1 && height > 1 && width <= 8000 && height <= 8000
    }

    if hasUsableBox(node) { return node }

    // No bounding box of its own: search the shallowest level of descendants
    // that contains framed nodes and return the largest one found there.
    var frontier = index.childrenByParent[node.id] ?? []
    var remainingDepth = 2
    while !frontier.isEmpty, remainingDepth > 0 {
      var deeper: [EaselParsedFigNode] = []
      var best: EaselParsedFigNode?
      var bestArea = 0.0
      for child in frontier {
        if hasUsableBox(child) {
          let area = (child.width ?? 0) * (child.height ?? 0)
          if area > bestArea {
            bestArea = area
            best = child
          }
        } else {
          deeper.append(contentsOf: index.childrenByParent[child.id] ?? [])
        }
      }
      if let best { return best }
      frontier = deeper
      remainingDepth -= 1
    }

    return nil
  }

  /// Largest dimension (px) a preview may have before it reads as a board or
  /// documentation page rather than a single screen. A 4K-ish screen still fits;
  /// tall spec pages (commonly 4000–6000px) do not.
  private static let maxPresentableExampleSide: Double = 2600
  /// Widest long-to-short ratio a preview may have before it renders as a sliver.
  private static let maxPresentableExampleAspect: Double = 6

  /// Whether a schematic preview is worth surfacing in the Examples gallery.
  ///
  /// The gallery scales each scene to fit a small tile (`preserveAspectRatio`),
  /// so oversized or extreme-aspect scenes — typically documentation boards
  /// rather than screens — collapse into an unreadable strip. Gating on size and
  /// aspect lets files made of real app screens keep their examples while files
  /// organized as spec pages drop them, and the section hides itself when none
  /// qualify.
  private static func isPresentableExampleScene(_ scene: EaselDesignSystemPreviewScene) -> Bool {
    let longSide = max(scene.width, scene.height)
    let shortSide = min(scene.width, scene.height)
    guard shortSide >= 24, longSide <= maxPresentableExampleSide else { return false }
    return longSide / shortSide <= maxPresentableExampleAspect
  }

  /// Keeps the legacy text-only `componentGroups` populated for back-compat with
  /// older readers; the tokens-first surfaces prefer `componentFamilies`.
  private static func makeComponentGroups(
    from components: [EaselDesignSystemManifestComponent]
  ) -> [EaselDesignSystemComponentGroup] {
    let grouped = Dictionary(grouping: components) { $0.category }
    return grouped.keys.sorted().prefix(8).map { category in
      let categoryComponents = (grouped[category] ?? [])
        .sorted { lhs, rhs in
          if lhs.confidence == rhs.confidence {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
          }
          return lhs.confidence > rhs.confidence
        }
        .prefix(12)

      return EaselDesignSystemComponentGroup(
        id: slug(for: category),
        title: category,
        summary: "Reference candidates found in local Figma components.",
        previewPath: nil,
        items: categoryComponents.map { component in
          EaselDesignSystemComponentItem(
            id: component.id,
            title: component.title,
            summary: component.summary
          )
        }
      )
    }
  }

  private static func makeSourceDiagnostics(
    from manifest: EaselDesignSystemManifest
  ) -> EaselDesignSystemSourceDiagnostics {
    let sources = manifest.sources
    let parsed = sources.filter { $0.status == .parsed }
    let failed = sources.filter { $0.status == .failed }
    let skipped = sources.filter { $0.status == .skipped }
    let parser = parsed.first

    var warnings: [String] = []
    if !manifest.components.isEmpty {
      warnings.append("Component families are grouped by Figma layer name and may be noisy.")
    }
    if !manifest.tokens.colors.isEmpty || !manifest.tokens.typography.isEmpty {
      warnings.append("Tokens are inferred from local node styles, not from a published token library.")
    }
    for source in failed {
      warnings.append("Could not parse \(source.fileName): \(source.errorMessage ?? "unknown error").")
    }

    return EaselDesignSystemSourceDiagnostics(
      parsedCount: parsed.count,
      failedCount: failed.count,
      skippedCount: skipped.count,
      totalNodeCount: sources.reduce(0) { $0 + $1.nodeCount },
      parserName: parser?.parserName,
      parserVersion: parser?.parserVersion,
      warnings: warnings
    )
  }

  private static func makeTokenSet(from records: [EaselFigImportRecord]) -> EaselDesignSystemTokenSet {
    EaselDesignSystemTokenSet(
      colors: makeColorTokens(from: records),
      typography: makeTypographyTokens(from: records),
      spacing: makeSpacingTokens(from: records),
      radii: makeRadiusTokens(from: records),
      effects: makeEffectTokens(from: records)
    )
  }

  private static func makeColorTokens(from records: [EaselFigImportRecord]) -> [EaselDesignSystemColorToken] {
    var buckets: [String: (count: Int, node: EaselParsedFigNode, fileName: String)] = [:]

    for record in records {
      guard let document = record.document else { continue }
      for node in document.nodes {
        for hex in (node.fillColors + node.strokeColors) where !hex.isEmpty {
          let current = buckets[hex] ?? (0, node, record.source.fileName)
          buckets[hex] = (current.count + 1, current.node, current.fileName)
        }
      }
    }

    return buckets
      .sorted { lhs, rhs in
        if lhs.value.count == rhs.value.count {
          return lhs.key < rhs.key
        }
        return lhs.value.count > rhs.value.count
      }
      .prefix(24)
      .enumerated()
      .map { index, element in
        let node = element.value.node
        return EaselDesignSystemColorToken(
          id: "color-\(index + 1)-\(slug(for: element.key))",
          name: tokenName(from: node.name, fallback: "Color \(index + 1)"),
          hex: element.key,
          sourceNodeID: node.id,
          sourceNodeName: node.name,
          confidence: node.name.localizedCaseInsensitiveContains("color") ? 0.82 : 0.62
        )
      }
  }

  private static func makeTypographyTokens(from records: [EaselFigImportRecord]) -> [EaselDesignSystemTypographyToken] {
    var buckets: [String: (count: Int, node: EaselParsedFigNode)] = [:]

    for record in records {
      guard let document = record.document else { continue }
      for node in document.nodes {
        guard let fontFamily = node.fontFamily, !fontFamily.isEmpty else { continue }
        let size = node.fontSize.map { String(format: "%.1f", $0) } ?? "unknown"
        let style = node.fontStyle ?? "Regular"
        let key = "\(fontFamily)|\(style)|\(size)"
        let current = buckets[key] ?? (0, node)
        buckets[key] = (current.count + 1, current.node)
      }
    }

    return buckets
      .sorted { lhs, rhs in
        if lhs.value.count == rhs.value.count {
          return lhs.key < rhs.key
        }
        return lhs.value.count > rhs.value.count
      }
      .prefix(16)
      .enumerated()
      .compactMap { index, element in
        let node = element.value.node
        guard let fontFamily = node.fontFamily else { return nil }
        let sizeText = node.fontSize.map { String(format: "%.0f", $0) }
        let fallbackName = [fontFamily, sizeText].compactMap { $0 }.joined(separator: " ")
        return EaselDesignSystemTypographyToken(
          id: "type-\(index + 1)-\(slug(for: fallbackName))",
          name: tokenName(from: node.name, fallback: fallbackName.isEmpty ? "Typography \(index + 1)" : fallbackName),
          fontFamily: fontFamily,
          fontStyle: node.fontStyle,
          fontSize: node.fontSize,
          sourceNodeID: node.id,
          sourceNodeName: node.name,
          confidence: node.name.localizedCaseInsensitiveContains("type") ? 0.82 : 0.60
        )
      }
  }

  private static func makeSpacingTokens(from records: [EaselFigImportRecord]) -> [EaselDesignSystemNumberToken] {
    numberTokens(
      from: records,
      names: ["space", "spacing", "gap"],
      value: { node in
        [node.width, node.height].compactMap { $0 }.filter { $0 > 0 && $0 <= 160 }.min()
      },
      idPrefix: "space",
      fallbackPrefix: "Spacing",
      maxCount: 16
    )
  }

  private static func makeRadiusTokens(from records: [EaselFigImportRecord]) -> [EaselDesignSystemNumberToken] {
    numberTokens(
      from: records,
      names: ["radius", "corner", "round"],
      value: { $0.cornerRadius },
      idPrefix: "radius",
      fallbackPrefix: "Radius",
      maxCount: 12
    )
  }

  private static func numberTokens(
    from records: [EaselFigImportRecord],
    names: [String],
    value: (EaselParsedFigNode) -> Double?,
    idPrefix: String,
    fallbackPrefix: String,
    maxCount: Int
  ) -> [EaselDesignSystemNumberToken] {
    var buckets: [String: (value: Double, count: Int, node: EaselParsedFigNode)] = [:]

    for record in records {
      guard let document = record.document else { continue }
      for node in document.nodes {
        guard names.contains(where: { node.name.localizedCaseInsensitiveContains($0) }),
              let numericValue = value(node),
              numericValue > 0 else {
          continue
        }

        let key = String(format: "%.2f", numericValue)
        let current = buckets[key] ?? (numericValue, 0, node)
        buckets[key] = (current.value, current.count + 1, current.node)
      }
    }

    return buckets
      .values
      .sorted { lhs, rhs in
        if lhs.value == rhs.value {
          return lhs.count > rhs.count
        }
        return lhs.value < rhs.value
      }
      .prefix(maxCount)
      .enumerated()
      .map { index, bucket in
        EaselDesignSystemNumberToken(
          id: "\(idPrefix)-\(slug(for: String(format: "%.0f", bucket.value)))",
          name: tokenName(from: bucket.node.name, fallback: "\(fallbackPrefix) \(index + 1)"),
          value: bucket.value,
          unit: "px",
          sourceNodeID: bucket.node.id,
          sourceNodeName: bucket.node.name,
          confidence: 0.74
        )
      }
  }

  private static func makeEffectTokens(from records: [EaselFigImportRecord]) -> [EaselDesignSystemEffectToken] {
    var tokens: [EaselDesignSystemEffectToken] = []
    var seen: Set<String> = []

    for record in records {
      guard let document = record.document else { continue }
      for node in document.nodes where !node.effectTypes.isEmpty {
        for effectType in node.effectTypes {
          let key = "\(effectType)-\(node.name)"
          guard seen.insert(key).inserted else { continue }
          tokens.append(EaselDesignSystemEffectToken(
            id: "effect-\(slug(for: key))",
            name: tokenName(from: node.name, fallback: effectType.capitalized),
            kind: effectType,
            sourceNodeID: node.id,
            sourceNodeName: node.name,
            confidence: 0.58
          ))
          if tokens.count >= 12 {
            return tokens
          }
        }
      }
    }

    return tokens
  }

  private static func makeComponents(from records: [EaselFigImportRecord]) -> [EaselDesignSystemManifestComponent] {
    struct ComponentFamilyBucket {
      var representative: EaselParsedFigNode
      var title: String
      var category: String
      var sourceFileName: String
      var confidence: Double
      var variantCount: Int
      // Variant property names in first-seen order, plus their distinct values.
      var propertyOrder: [String]
      var propertyValues: [String: [String]]

      mutating func add(variantPropertiesFrom name: String) {
        for (propertyName, value) in EaselDesignSystemManifestNormalizer.parseVariantProperties(name) {
          if propertyValues[propertyName] == nil {
            propertyOrder.append(propertyName)
            propertyValues[propertyName] = []
          }
          if propertyValues[propertyName]?.contains(value) == false {
            propertyValues[propertyName]?.append(value)
          }
        }
      }

      var variantProperties: [EaselDesignSystemVariantProperty] {
        propertyOrder.map { propertyName in
          EaselDesignSystemVariantProperty(
            id: EaselDesignSystemManifestNormalizer.slug(for: propertyName),
            name: propertyName,
            values: propertyValues[propertyName] ?? []
          )
        }
      }
    }

    var buckets: [String: ComponentFamilyBucket] = [:]
    var seenNodeIDs: Set<String> = []

    for record in records {
      guard let document = record.document else { continue }
      let nodesByID = Dictionary(uniqueKeysWithValues: document.nodes.map { ($0.id, $0) })
      // A frame that is the parent of variant nodes (named like
      // "Kind=filled, Status=primary") is the variant-set container, not a
      // variant itself — exclude it so it doesn't inflate the variant count.
      var variantSetParentIDs: Set<String> = []
      for node in document.nodes where isVariantPropertyBag(node.name) {
        if let parentID = node.parentID {
          variantSetParentIDs.insert(parentID)
        }
      }

      for node in document.nodes {
        guard isComponentCandidate(node),
              !variantSetParentIDs.contains(node.id),
              seenNodeIDs.insert("\(record.source.fileName)-\(node.id)").inserted else {
          continue
        }

        let title = componentFamilyTitle(for: node, nodesByID: nodesByID)
        let category = category(for: title)
        let familyKey = "\(record.source.fileName)-\(category)-\(slug(for: title))"
        let confidence = componentConfidence(for: node, familyTitle: title)
        guard confidence >= 0.58 else { continue }

        if var bucket = buckets[familyKey] {
          bucket.variantCount += 1
          if confidence > bucket.confidence {
            bucket.representative = node
            bucket.confidence = confidence
          }
          bucket.add(variantPropertiesFrom: node.name)
          buckets[familyKey] = bucket
        } else {
          var bucket = ComponentFamilyBucket(
            representative: node,
            title: title,
            category: category,
            sourceFileName: record.source.fileName,
            confidence: confidence,
            variantCount: 1,
            propertyOrder: [],
            propertyValues: [:]
          )
          bucket.add(variantPropertiesFrom: node.name)
          buckets[familyKey] = bucket
        }
      }
    }

    let components = buckets
      .values
      .map { bucket in
        let representative = bucket.representative
        let confidence = min(bucket.confidence + min(Double(bucket.variantCount) / 1_000, 0.08), 0.96)
        return EaselDesignSystemManifestComponent(
          id: "component-\(slug(for: "\(bucket.sourceFileName)-\(bucket.category)-\(bucket.title)"))",
          title: bucket.title,
          summary: componentSummary(
            for: representative,
            category: bucket.category,
            familyTitle: bucket.title,
            variantCount: bucket.variantCount
          ),
          category: bucket.category,
          sourceFileName: bucket.sourceFileName,
          sourceNodeID: representative.id,
          sourceNodeName: representative.name,
          sourcePageName: representative.pageName,
          sourceNodeType: representative.type,
          childCount: representative.childCount,
          variantCount: bucket.variantCount,
          variantProperties: bucket.variantProperties,
          confidence: confidence
        )
      }

    return components
      .sorted { lhs, rhs in
        if lhs.confidence == rhs.confidence {
          return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhs.confidence > rhs.confidence
      }
      .prefix(80)
      .map { $0 }
  }

  /// Parses a Figma variant node name such as
  /// `"Kind=filled, Status=primary, State=default, Size=sm"` into ordered
  /// `(propertyName, value)` pairs. Returns `[]` for non-variant names.
  static func parseVariantProperties(_ name: String) -> [(name: String, value: String)] {
    name
      .split(separator: ",")
      .compactMap { segment in
        let parts = segment.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let propertyName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propertyName.isEmpty, !value.isEmpty else { return nil }
        return (propertyName, value)
      }
  }

  private static func makeReferences(
    from records: [EaselFigImportRecord],
    importMode: EaselDesignSystemFigImportMode
  ) -> [EaselDesignSystemManifestReference] {
    var references: [EaselDesignSystemManifestReference] = []
    var seen: Set<String> = []

    for record in records {
      guard let document = record.document else { continue }
      for node in document.nodes {
        guard isReferenceCandidate(node),
              !isInternalPageName(node.pageName),
              !isInternalPageName(node.name),
              seen.insert("\(record.source.fileName)-\(node.id)").inserted else {
          continue
        }

        references.append(EaselDesignSystemManifestReference(
          id: "reference-\(slug(for: "\(record.source.fileName)-\(node.id)-\(node.name)"))",
          title: displayTitle(for: node.name, fallback: node.type.capitalized),
          summary: referenceSummary(for: node, importMode: importMode),
          sourceFileName: record.source.fileName,
          sourceNodeID: node.id,
          sourceNodeName: node.name,
          sourcePageName: node.pageName,
          sourceNodeType: node.type,
          confidence: node.depth <= 2 ? 0.72 : 0.52
        ))
      }
    }

    return references
      .sorted { lhs, rhs in
        if lhs.confidence == rhs.confidence {
          return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhs.confidence > rhs.confidence
      }
      .prefix(60)
      .map { $0 }
  }

  private static func makeSummary(
    importMode: EaselDesignSystemFigImportMode,
    parsedCount: Int,
    sourceCount: Int,
    colorCount: Int,
    typographyCount: Int,
    componentCount: Int,
    referenceCount: Int
  ) -> String {
    if importMode == .reference {
      return "\(sourceCount) local .fig source file(s) attached to this design system."
    }

    guard parsedCount > 0 else {
      return "\(sourceCount) local .fig source file(s) were attached, but none could be parsed."
    }

    var parts: [String] = []
    if colorCount > 0 {
      parts.append("\(colorCount) color\(colorCount == 1 ? "" : "s")")
    }
    if typographyCount > 0 {
      parts.append("\(typographyCount) text style\(typographyCount == 1 ? "" : "s")")
    }
    if componentCount > 0 {
      parts.append("\(componentCount) component famil\(componentCount == 1 ? "y" : "ies")")
    }

    guard !parts.isEmpty else {
      return "Parsed \(parsedCount) local .fig file(s); no high-confidence tokens or components were detected."
    }

    return "Local snapshot parsed from \(parsedCount) .fig file(s): \(listPhrase(parts))."
  }

  private static func listPhrase(_ parts: [String]) -> String {
    switch parts.count {
    case 0: return ""
    case 1: return parts[0]
    case 2: return "\(parts[0]) and \(parts[1])"
    default: return "\(parts.dropLast().joined(separator: ", ")), and \(parts[parts.count - 1])"
    }
  }

  private static func isComponentCandidate(_ node: EaselParsedFigNode) -> Bool {
    let type = node.type.uppercased()
    if type.contains("SYMBOL") || type.contains("COMPONENT") || type == "INSTANCE" {
      return true
    }

    let name = node.name.lowercased()
    let componentTerms = [
      "button", "input", "field", "card", "modal", "dialog", "nav", "tab", "menu",
      "badge", "chip", "avatar", "toast", "tooltip", "checkbox", "radio", "switch",
      "dropdown", "select", "list", "table", "banner"
    ]
    return node.childCount > 0 && componentTerms.contains { name.contains($0) }
  }

  private static func isReferenceCandidate(_ node: EaselParsedFigNode) -> Bool {
    let type = node.type.uppercased()
    guard type == "CANVAS" || type == "FRAME" || type.contains("COMPONENT") || type.contains("SYMBOL") else {
      return false
    }

    if node.depth <= 2 && node.childCount > 0 {
      return true
    }

    let name = node.name.lowercased()
    return ["screen", "page", "flow", "example", "reference", "template"].contains { name.contains($0) }
  }

  private static func componentConfidence(for node: EaselParsedFigNode, familyTitle: String) -> Double {
    let type = node.type.uppercased()
    let name = "\(node.name) \(familyTitle)".lowercased()
    var confidence = 0.48

    if type.contains("COMPONENT") || type.contains("SYMBOL") {
      confidence += 0.28
    }
    if name.contains("/") || name.contains("=") {
      confidence += 0.08
    }
    if node.childCount > 0 {
      confidence += 0.10
    }
    if node.pageName?.localizedCaseInsensitiveContains("component") == true {
      confidence += 0.08
    }
    if familyTitle.localizedCaseInsensitiveCompare(node.name) != .orderedSame {
      confidence += 0.06
    }
    if isInternalPageName(node.pageName) {
      confidence -= 0.16
    }

    return min(max(confidence, 0), 0.96)
  }

  private static func category(for name: String) -> String {
    let lowered = name.lowercased()
    let categories: [(String, String)] = [
      ("button", "Buttons"),
      ("input", "Inputs"),
      ("field", "Inputs"),
      ("select", "Inputs"),
      ("checkbox", "Inputs"),
      ("radio", "Inputs"),
      ("switch", "Inputs"),
      ("card", "Cards"),
      ("modal", "Overlays"),
      ("dialog", "Overlays"),
      ("toast", "Overlays"),
      ("tooltip", "Overlays"),
      ("nav", "Navigation"),
      ("tab", "Navigation"),
      ("menu", "Navigation"),
      ("badge", "Indicators"),
      ("chip", "Indicators"),
      ("avatar", "Media"),
      ("icon", "Media"),
      ("logo", "Media"),
      ("brand", "Media")
    ]

    return categories.first { lowered.contains($0.0) }?.1 ?? "Components"
  }

  private static func componentSummary(
    for node: EaselParsedFigNode,
    category: String,
    familyTitle: String,
    variantCount: Int
  ) -> String {
    let itemKind = category.dropLastIfPlural()
    let variantText = variantCount > 1 ? "\(variantCount) variants" : "1 candidate"

    if let pageName = node.pageName, !pageName.isEmpty, !isInternalPageName(pageName) {
      if pageName.localizedCaseInsensitiveCompare(familyTitle) == .orderedSame {
        return "\(itemKind) family with \(variantText)."
      }
      return "\(itemKind) family from \(pageName), with \(variantText)."
    }
    return "\(itemKind) family with \(variantText) from local Figma components."
  }

  private static func componentFamilyTitle(
    for node: EaselParsedFigNode,
    nodesByID: [String: EaselParsedFigNode]
  ) -> String {
    if isVariantPropertyBag(node.name) {
      var current = node
      while let parentID = current.parentID, let parent = nodesByID[parentID] {
        if let title = cleanComponentFamilyName(parent.name) {
          return title
        }
        current = parent
      }

      if let pageName = node.pageName, let title = cleanComponentFamilyName(pageName) {
        return title
      }
    }

    return displayTitle(for: node.name, fallback: node.pageName ?? "Component")
  }

  private static func cleanComponentFamilyName(_ rawName: String) -> String? {
    let trimmed = rawName
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    guard !trimmed.isEmpty else { return nil }

    let lowered = trimmed.lowercased()
    let ignoredTerms = [
      "document", "canvas", "page", "internal", "private", "scratch",
      "unpublished", "base component", "base components"
    ]
    guard !ignoredTerms.contains(where: { lowered.contains($0) }) else {
      return nil
    }

    return displayTitle(for: trimmed, fallback: "Component")
  }

  private static func isVariantPropertyBag(_ name: String) -> Bool {
    name.contains("=") && name.contains(",")
  }

  private static func isInternalPageName(_ name: String?) -> Bool {
    guard let name else { return false }
    return name.localizedCaseInsensitiveContains("internal")
      || name.localizedCaseInsensitiveContains("private")
      || name.localizedCaseInsensitiveContains("scratch")
  }

  private static func referenceSummary(
    for node: EaselParsedFigNode,
    importMode: EaselDesignSystemFigImportMode
  ) -> String {
    switch importMode {
    case .reference:
      return "Source frame for visual direction and product examples."
    case .extractCatalog:
      return "Source frame used while extracting reusable design system details."
    }
  }

  private static func tokenName(from rawName: String, fallback: String) -> String {
    let cleaned = displayTitle(for: rawName, fallback: fallback)
    return cleaned.isEmpty ? fallback : cleaned
  }

  private static func displayTitle(for rawName: String, fallback: String) -> String {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }

    let normalized = trimmed
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "/", with: " / ")
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
    return normalized
  }

  private static func slug(for value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let allowed = CharacterSet.alphanumerics
    var result = ""
    var previousWasSeparator = false

    for scalar in folded.unicodeScalars {
      if allowed.contains(scalar) {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if !previousWasSeparator {
        result.append("-")
        previousWasSeparator = true
      }
    }

    let trimmed = result
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      .lowercased()
    return trimmed.isEmpty ? "item" : trimmed
  }
}

private extension String {
  func dropLastIfPlural() -> String {
    hasSuffix("s") ? String(dropLast()) : self
  }
}

private extension EaselParsedFigNode {
  var sourceDescription: String {
    if let pageName, !pageName.isEmpty {
      return pageName
    }
    return type.capitalized
  }
}
