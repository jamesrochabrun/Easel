//
//  EaselDesignSystemManager.swift
//  EaselChat
//

import Foundation

public protocol EaselDesignSystemManaging: Sendable {
  func loadDesignSystems() async throws -> [EaselDesignSystemProfile]
  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile
  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog?
}

public enum EaselDesignSystemManagerError: LocalizedError, Equatable, Sendable {
  case missingDesignSystemDirectory(String)
  case emptyDesignSystemDescription

  public var errorDescription: String? {
    switch self {
    case .missingDesignSystemDirectory:
      return "The selected design system folder could not be found."
    case .emptyDesignSystemDescription:
      return "Add a company or design system description before creating a design system."
    }
  }
}

public actor LocalEaselDesignSystemManager: EaselDesignSystemManaging {
  private let rootDirectory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  private static let metadataDirectoryName = ".easel"
  private static let metadataFileName = "design-system.json"
  private static let catalogFileName = "catalog.json"

  public init(
    rootDirectory: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)

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
    try importResources(from: request, into: directoryURL)
    try writeMetadata(profile, in: directoryURL)
    return profile
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

  private func importResources(from request: EaselDesignSystemCreateRequest, into directoryURL: URL) throws {
    let resourcesURL = directoryURL.appendingPathComponent("resources", isDirectory: true)

    try copySources(
      request.codeSourceURLs,
      to: resourcesURL.appendingPathComponent("code", isDirectory: true),
      skipsGeneratedFolders: true
    )
    try copySources(
      request.figFileURLs,
      to: resourcesURL.appendingPathComponent("figma", isDirectory: true),
      skipsGeneratedFolders: false
    )
    try copySources(
      request.assetURLs,
      to: resourcesURL.appendingPathComponent("assets", isDirectory: true),
      skipsGeneratedFolders: true
    )
  }

  private func copySources(_ sourceURLs: [URL], to destinationDirectory: URL, skipsGeneratedFolders: Bool) throws {
    guard !sourceURLs.isEmpty else { return }
    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

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
    let title = escapedHTML(profile.name)
    let blurb = escapedHTML(profile.blurb)

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(title)</title>
      <style>
        :root {
          color-scheme: light;
          --ink: #22201d;
          --muted: #6f6a63;
          --surface: #fbfaf8;
          --line: #dedbd5;
        }

        * {
          box-sizing: border-box;
        }

        body {
          margin: 0;
          min-height: 100vh;
          font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          color: var(--ink);
          background: var(--surface);
        }

        main {
          width: min(920px, calc(100vw - 40px));
          margin: 0 auto;
          padding: 72px 0;
        }

        h1 {
          margin: 0 0 16px;
          font-size: clamp(40px, 8vw, 84px);
          line-height: 0.95;
          letter-spacing: 0;
        }

        p {
          max-width: 680px;
          margin: 0;
          color: var(--muted);
          font-size: 18px;
          line-height: 1.55;
        }

        .panel {
          margin-top: 40px;
          border: 1px solid var(--line);
          border-radius: 8px;
          padding: 24px;
          background: white;
        }
      </style>
    </head>
    <body>
      <main>
        <h1>\(title)</h1>
        <p>\(blurb)</p>
        <div class="panel">
          <p>Codex will replace this scaffold with a browsable component catalog and write metadata to <code>.easel/catalog.json</code>.</p>
        </div>
      </main>
    </body>
    </html>
    """
  }

  private func escapedHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
  }

  private func write(_ contents: String, to url: URL) throws {
    try contents.data(using: .utf8)?.write(to: url, options: .atomic)
  }
}
