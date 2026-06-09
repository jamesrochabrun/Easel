//
//  EaselDesignSystemManager.swift
//  EaselChat
//

import Foundation

public protocol EaselDesignSystemManaging: Sendable {
  func loadDesignSystems() async throws -> [EaselDesignSystemProfile]
  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile
  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws
  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog?
  /// Re-runs the import pipeline for an existing design system using the `.fig`
  /// sources already stored under `resources/figma`, reusing the parser's cached
  /// output. Use this to pick up improvements to the import/catalog logic
  /// without re-selecting files or re-parsing the source.
  @discardableResult
  func regenerateDesignSystem(forDesignSystemAt path: String) async throws -> EaselDesignSystemImportResult
}

public extension EaselDesignSystemManaging {
  // Default no-op so managers that don't manage local sources (e.g. test stubs)
  // need not implement regeneration.
  @discardableResult
  func regenerateDesignSystem(forDesignSystemAt path: String) async throws -> EaselDesignSystemImportResult {
    EaselDesignSystemImportResult(manifest: nil, catalog: nil)
  }
}

public enum EaselDesignSystemImportScheduling: Sendable {
  case background
  case immediate
}

public enum EaselDesignSystemManagerError: LocalizedError, Equatable, Sendable {
  case missingDesignSystemDirectory(String)
  case emptyDesignSystemDescription
  case designSystemNotFound
  case noFigSourcesToRegenerate

  public var errorDescription: String? {
    switch self {
    case .missingDesignSystemDirectory:
      return "The selected design system folder could not be found."
    case .emptyDesignSystemDescription:
      return "Add a company or design system description before creating a design system."
    case .designSystemNotFound:
      return "The design system could not be found."
    case .noFigSourcesToRegenerate:
      return "This design system has no stored Figma files to regenerate from."
    }
  }
}

public actor LocalEaselDesignSystemManager: EaselDesignSystemManaging {
  private let rootDirectory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let designSystemImporter: any EaselDesignSystemImporting
  private let importScheduling: EaselDesignSystemImportScheduling

  private static let metadataDirectoryName = ".easel"
  private static let metadataFileName = "design-system.json"
  private static let catalogFileName = "catalog.json"
  private static let manifestFileName = "design-system-manifest.json"

  public init(
    rootDirectory: URL? = nil,
    fileManager: FileManager = .default,
    designSystemImporter: any EaselDesignSystemImporting = LocalEaselDesignSystemImporter(),
    importScheduling: EaselDesignSystemImportScheduling = .background
  ) {
    self.fileManager = fileManager
    self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
    self.designSystemImporter = designSystemImporter
    self.importScheduling = importScheduling

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func loadDesignSystems() async throws -> [EaselDesignSystemProfile] {
    try ensureRootDirectoryExists()

    var profiles: [EaselDesignSystemProfile] = []
    for directoryURL in try designSystemDirectoryURLs() {
      let metadataURL = Self.metadataURL(for: directoryURL)
      guard fileManager.fileExists(atPath: metadataURL.path) else {
        continue
      }

      do {
        let data = try Data(contentsOf: metadataURL)
        profiles.append(try decoder.decode(EaselDesignSystemProfile.self, from: data))
      } catch {
        continue
      }
    }

    return profiles.sorted { lhs, rhs in
      if lhs.updatedAt == rhs.updatedAt {
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      return lhs.updatedAt > rhs.updatedAt
    }
  }

  public func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    try ensureRootDirectoryExists()

    let blurb = request.blurb.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !blurb.isEmpty else {
      throw EaselDesignSystemManagerError.emptyDesignSystemDescription
    }

    let name = designSystemName(from: blurb)
    let directoryURL = uniqueDirectoryURL(for: name)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let now = Date()
    let profile = EaselDesignSystemProfile(
      id: UUID(),
      name: name,
      blurb: blurb,
      notes: request.notes.trimmingCharacters(in: .whitespacesAndNewlines),
      sourceLinks: normalizedLinks(request.sourceLinks),
      workingDirectory: directoryURL.path,
      createdAt: now,
      updatedAt: now
    )

    try writeScaffold(for: profile, at: directoryURL)
    let importedResources = try importResources(from: request, into: directoryURL)
    try writeMetadata(profile, in: directoryURL)
    await scheduleImportIfNeeded(
      profile: profile,
      directoryURL: directoryURL,
      figFileURLs: importedResources.figFileURLs,
      importMode: request.figImportMode
    )
    return profile
  }

  public func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {
    try ensureRootDirectoryExists()

    guard let directoryURL = try designSystemDirectoryURL(matching: profile.id) else {
      throw EaselDesignSystemManagerError.designSystemNotFound
    }

    try fileManager.removeItem(at: directoryURL)
  }

  public func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    let directoryURL = try validatedDesignSystemURL(for: path)
    let catalogURL = Self.catalogURL(for: directoryURL)

    guard fileManager.fileExists(atPath: catalogURL.path) else {
      return nil
    }

    let data = try Data(contentsOf: catalogURL)
    return try decoder.decode(EaselDesignSystemCatalog.self, from: data)
  }

  @discardableResult
  public func regenerateDesignSystem(forDesignSystemAt path: String) async throws -> EaselDesignSystemImportResult {
    let directoryURL = try validatedDesignSystemURL(for: path)

    let metadataURL = Self.metadataURL(for: directoryURL)
    guard fileManager.fileExists(atPath: metadataURL.path) else {
      throw EaselDesignSystemManagerError.designSystemNotFound
    }
    let profile = try decoder.decode(
      EaselDesignSystemProfile.self,
      from: try Data(contentsOf: metadataURL)
    )

    let figFileURLs = try storedFigFileURLs(in: directoryURL)
    guard !figFileURLs.isEmpty else {
      throw EaselDesignSystemManagerError.noFigSourcesToRegenerate
    }

    // Re-run the import against the retained sources. The parser caches its
    // output by file hash under `.easel/imports`, so an unchanged `.fig` skips
    // the expensive parse and only the manifest/catalog are rebuilt.
    let request = EaselDesignSystemImportRequest(
      profile: profile,
      directoryURL: directoryURL,
      figFileURLs: figFileURLs,
      importMode: storedImportMode(in: directoryURL)
    )
    return await designSystemImporter.importDesignSystemResources(request)
  }

  private static func defaultRootDirectory(fileManager: FileManager) -> URL {
    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
      return documentsURL.appendingPathComponent("Easel Design Systems", isDirectory: true)
    }

    return URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent("Easel Design Systems", isDirectory: true)
  }

  private static func metadataURL(for directoryURL: URL) -> URL {
    directoryURL
      .appendingPathComponent(metadataDirectoryName, isDirectory: true)
      .appendingPathComponent(metadataFileName)
  }

  private static func catalogURL(for directoryURL: URL) -> URL {
    directoryURL
      .appendingPathComponent(metadataDirectoryName, isDirectory: true)
      .appendingPathComponent(catalogFileName)
  }

  private func ensureRootDirectoryExists() throws {
    try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
  }

  /// `.fig` sources retained under `resources/figma` for an imported design system.
  private func storedFigFileURLs(in directoryURL: URL) throws -> [URL] {
    let figmaURL = directoryURL
      .appendingPathComponent("resources", isDirectory: true)
      .appendingPathComponent("figma", isDirectory: true)
    guard fileManager.fileExists(atPath: figmaURL.path) else { return [] }
    return try fileManager.contentsOfDirectory(
      at: figmaURL,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )
    .filter { $0.pathExtension.lowercased() == "fig" }
    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
  }

  /// Import mode recorded in the existing manifest, so regeneration preserves how
  /// the design system was originally imported (extract vs. reference).
  private func storedImportMode(in directoryURL: URL) -> EaselDesignSystemFigImportMode {
    let manifestURL = directoryURL
      .appendingPathComponent(Self.metadataDirectoryName, isDirectory: true)
      .appendingPathComponent(Self.manifestFileName)
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? decoder.decode(EaselDesignSystemManifest.self, from: data) else {
      return .extractCatalog
    }
    return manifest.importMode
  }

  private func designSystemDirectoryURLs() throws -> [URL] {
    let directoryURLs = try fileManager.contentsOfDirectory(
      at: rootDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    return try directoryURLs.filter { directoryURL in
      try directoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    }
  }

  private func designSystemDirectoryURL(matching designSystemID: UUID) throws -> URL? {
    for directoryURL in try designSystemDirectoryURLs() {
      let metadataURL = Self.metadataURL(for: directoryURL)
      guard fileManager.fileExists(atPath: metadataURL.path) else {
        continue
      }

      do {
        let data = try Data(contentsOf: metadataURL)
        let profile = try decoder.decode(EaselDesignSystemProfile.self, from: data)
        if profile.id == designSystemID {
          return directoryURL
        }
      } catch {
        continue
      }
    }

    return nil
  }

  private func validatedDesignSystemURL(for path: String) throws -> URL {
    let url = URL(fileURLWithPath: path)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw EaselDesignSystemManagerError.missingDesignSystemDirectory(path)
    }

    return url
  }

  private func writeMetadata(_ profile: EaselDesignSystemProfile, in directoryURL: URL) throws {
    let metadataDirectory = directoryURL.appendingPathComponent(Self.metadataDirectoryName, isDirectory: true)
    try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    let data = try encoder.encode(profile)
    try data.write(to: Self.metadataURL(for: directoryURL), options: .atomic)
  }

  private func writeScaffold(for profile: EaselDesignSystemProfile, at directoryURL: URL) throws {
    try fileManager.createDirectory(
      at: directoryURL.appendingPathComponent("resources", isDirectory: true),
      withIntermediateDirectories: true
    )

    try write(packageJSON(for: profile), to: directoryURL.appendingPathComponent("package.json"))
    try write(readme(for: profile), to: directoryURL.appendingPathComponent("README.md"))
    try write(indexHTML(for: profile), to: directoryURL.appendingPathComponent("index.html"))
  }

  private func importResources(from request: EaselDesignSystemCreateRequest, into directoryURL: URL) throws -> ImportedDesignSystemResourceURLs {
    let resourcesURL = directoryURL.appendingPathComponent("resources", isDirectory: true)

    try copySources(
      request.codeSourceURLs,
      to: resourcesURL.appendingPathComponent("code", isDirectory: true),
      skipsGeneratedFolders: true
    )
    let figFileURLs = try copySources(
      request.figFileURLs,
      to: resourcesURL.appendingPathComponent("figma", isDirectory: true),
      skipsGeneratedFolders: false
    )
    try copySources(
      request.assetURLs,
      to: resourcesURL.appendingPathComponent("assets", isDirectory: true),
      skipsGeneratedFolders: true
    )

    return ImportedDesignSystemResourceURLs(figFileURLs: figFileURLs)
  }

  @discardableResult
  private func copySources(_ sourceURLs: [URL], to destinationDirectory: URL, skipsGeneratedFolders: Bool) throws -> [URL] {
    guard !sourceURLs.isEmpty else { return [] }
    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    var copiedURLs: [URL] = []

    for sourceURL in sourceURLs {
      let isAccessing = sourceURL.startAccessingSecurityScopedResource()
      defer {
        if isAccessing {
          sourceURL.stopAccessingSecurityScopedResource()
        }
      }

      let source = sourceURL.standardizedFileURL
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
        continue
      }

      let destination = uniqueDestinationURL(
        for: sanitizedFileName(source.lastPathComponent),
        in: destinationDirectory
      )

      if isDirectory.boolValue {
        try copyDirectory(
          from: source,
          to: destination,
          skipsGeneratedFolders: skipsGeneratedFolders
        )
      } else {
        try fileManager.copyItem(at: source, to: destination)
      }
      copiedURLs.append(destination)
    }

    return copiedURLs
  }

  private func scheduleImportIfNeeded(
    profile: EaselDesignSystemProfile,
    directoryURL: URL,
    figFileURLs: [URL],
    importMode: EaselDesignSystemFigImportMode
  ) async {
    guard !figFileURLs.isEmpty else { return }

    let request = EaselDesignSystemImportRequest(
      profile: profile,
      directoryURL: directoryURL,
      figFileURLs: figFileURLs,
      importMode: importMode
    )

    switch importScheduling {
    case .background:
      let importer = designSystemImporter
      Task.detached(priority: .utility) {
        _ = await importer.importDesignSystemResources(request)
      }
    case .immediate:
      _ = await designSystemImporter.importDesignSystemResources(request)
    }
  }

  private func copyDirectory(from source: URL, to destination: URL, skipsGeneratedFolders: Bool) throws {
    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

    guard let enumerator = fileManager.enumerator(atPath: source.path) else {
      return
    }

    for case let relativePath as String in enumerator {
      guard !relativePath.isEmpty else { continue }

      let itemURL = source.appendingPathComponent(relativePath)
      if skipsGeneratedFolders, shouldSkipDirectory(itemURL) {
        enumerator.skipDescendants()
        continue
      }

      let destinationURL = destination.appendingPathComponent(relativePath)
      let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
      if values.isDirectory == true {
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
      } else {
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: itemURL, to: destinationURL)
      }
    }
  }

  private func shouldSkipDirectory(_ url: URL) -> Bool {
    let skippedNames: Set<String> = [".git", "node_modules", ".build", "build", "dist", "DerivedData"]
    let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
    return values?.isDirectory == true && skippedNames.contains(url.lastPathComponent)
  }

  private func designSystemName(from blurb: String) -> String {
    let firstLine = blurb
      .split(whereSeparator: \.isNewline)
      .first
      .map(String.init) ?? blurb
    let firstClause = firstLine
      .split(separator: ":", maxSplits: 1)
      .first
      .map(String.init) ?? firstLine
    let trimmed = firstClause.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      return "Untitled Design System"
    }

    let limit = 60
    if trimmed.count <= limit {
      return trimmed
    }

    return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func normalizedLinks(_ links: [String]) -> [String] {
    links
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func uniqueDirectoryURL(for name: String) -> URL {
    let baseSlug = slug(for: name)
    var candidate = rootDirectory.appendingPathComponent(baseSlug, isDirectory: true)
    var suffix = 2

    while fileManager.fileExists(atPath: candidate.path) {
      candidate = rootDirectory.appendingPathComponent("\(baseSlug)-\(suffix)", isDirectory: true)
      suffix += 1
    }

    return candidate
  }

  private func uniqueDestinationURL(for fileName: String, in directoryURL: URL) -> URL {
    var candidate = directoryURL.appendingPathComponent(fileName)
    guard !fileManager.fileExists(atPath: candidate.path) else {
      let fileURL = URL(fileURLWithPath: fileName)
      let pathExtension = fileURL.pathExtension
      let baseName = pathExtension.isEmpty ? fileName : String(fileName.dropLast(pathExtension.count + 1))
      var suffix = 2

      repeat {
        let nextFileName = pathExtension.isEmpty
          ? "\(baseName) \(suffix)"
          : "\(baseName) \(suffix).\(pathExtension)"
        candidate = directoryURL.appendingPathComponent(nextFileName)
        suffix += 1
      } while fileManager.fileExists(atPath: candidate.path)

      return candidate
    }

    return candidate
  }

  private func sanitizedFileName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Resource" : trimmed
  }

  private func slug(for name: String) -> String {
    let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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
    return trimmed.isEmpty ? "untitled-design-system" : trimmed
  }

  private func packageJSON(for profile: EaselDesignSystemProfile) -> String {
    """
    {
      "name": "\(slug(for: profile.name))",
      "private": true,
      "version": "0.1.0",
      "scripts": {
        "dev": "python3 -c \\"import http.server, socketserver; socketserver.TCPServer.allow_reuse_address = True; server = socketserver.TCPServer(('127.0.0.1', 0), http.server.SimpleHTTPRequestHandler); print(f'Local: http://localhost:{server.server_address[1]}', flush=True); server.serve_forever()\\""
      }
    }
    """
  }

  private func readme(for profile: EaselDesignSystemProfile) -> String {
    """
    # \(profile.name)

    Created by Codex Design.

    \(profile.blurb)

    Add source code, .fig files, fonts, logos, and assets under `resources/`.
    Codex should write the generated component catalog to `.easel/catalog.json`.

    Run `npm run dev` to preview this design system in Codex Design.
    """
  }

  private func indexHTML(for profile: EaselDesignSystemProfile) -> String {
    EaselDesignSystemCatalogHTMLRenderer.html(title: profile.name, blurb: profile.blurb)
  }

  private func write(_ contents: String, to url: URL) throws {
    try contents.data(using: .utf8)?.write(to: url, options: .atomic)
  }
}

private struct ImportedDesignSystemResourceURLs {
  let figFileURLs: [URL]
}
