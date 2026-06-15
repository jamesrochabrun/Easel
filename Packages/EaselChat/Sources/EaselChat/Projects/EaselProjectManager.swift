//
//  EaselProjectManager.swift
//  EaselChat
//

import EaselDesignSystems
import EaselSlides
import Foundation

public protocol EaselProjectManaging: Sendable {
  func loadProjects() async throws -> [EaselDesignProject]
  func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject
  func deleteProject(_ project: EaselDesignProject) async throws
}

enum EaselProjectManagerError: LocalizedError {
  case projectNotFound

  var errorDescription: String? {
    switch self {
    case .projectNotFound:
      return "The project could not be found."
    }
  }
}

public actor LocalEaselProjectManager: EaselProjectManaging {
  private let rootDirectory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

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

  public func loadProjects() async throws -> [EaselDesignProject] {
    try ensureRootDirectoryExists()

    var projects: [EaselDesignProject] = []
    for directoryURL in try projectDirectoryURLs() {
      let metadataURL = Self.metadataURL(for: directoryURL)
      guard fileManager.fileExists(atPath: metadataURL.path) else {
        continue
      }

      do {
        let data = try Data(contentsOf: metadataURL)
        projects.append(try decoder.decode(EaselDesignProject.self, from: data))
      } catch {
        continue
      }
    }

    return projects.sorted { lhs, rhs in
      if lhs.updatedAt == rhs.updatedAt {
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      return lhs.updatedAt > rhs.updatedAt
    }
  }

  public func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject {
    try ensureRootDirectoryExists()

    let projectName = normalizedProjectName(request.name, kind: request.kind)
    let directoryURL = uniqueDirectoryURL(for: projectName)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let now = Date()
    let fidelity = effectiveFidelity(for: request)
    let project = EaselDesignProject(
      id: UUID(),
      name: projectName,
      kind: request.kind,
      designSystem: request.designSystem,
      fidelity: fidelity,
      workingDirectory: directoryURL.path,
      createdAt: now,
      updatedAt: now
    )

    try writeScaffold(for: project, at: directoryURL)
    try writeMetadata(project, in: directoryURL)
    return project
  }

  public func deleteProject(_ project: EaselDesignProject) async throws {
    try ensureRootDirectoryExists()

    guard let directoryURL = try projectDirectoryURL(matching: project.id) else {
      throw EaselProjectManagerError.projectNotFound
    }

    try fileManager.removeItem(at: directoryURL)
  }

  private static func defaultRootDirectory(fileManager: FileManager) -> URL {
    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
      return documentsURL.appendingPathComponent("Easel Projects", isDirectory: true)
    }

    return URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent("Easel Projects", isDirectory: true)
  }

  private static func metadataURL(for directoryURL: URL) -> URL {
    directoryURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("project.json")
  }

  private func ensureRootDirectoryExists() throws {
    try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
  }

  private func projectDirectoryURLs() throws -> [URL] {
    let directoryURLs = try fileManager.contentsOfDirectory(
      at: rootDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    return try directoryURLs.filter { directoryURL in
      try directoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    }
  }

  private func projectDirectoryURL(matching projectID: UUID) throws -> URL? {
    for directoryURL in try projectDirectoryURLs() {
      let metadataURL = Self.metadataURL(for: directoryURL)
      guard fileManager.fileExists(atPath: metadataURL.path) else {
        continue
      }

      do {
        let data = try Data(contentsOf: metadataURL)
        let project = try decoder.decode(EaselDesignProject.self, from: data)
        if project.id == projectID {
          return directoryURL
        }
      } catch {
        continue
      }
    }

    return nil
  }

  private func writeMetadata(_ project: EaselDesignProject, in directoryURL: URL) throws {
    let metadataDirectory = directoryURL.appendingPathComponent(".easel", isDirectory: true)
    try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    let data = try encoder.encode(project)
    try data.write(to: Self.metadataURL(for: directoryURL), options: .atomic)
  }

  private func writeScaffold(for project: EaselDesignProject, at directoryURL: URL) throws {
    try fileManager.createDirectory(
      at: directoryURL.appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true),
      withIntermediateDirectories: true
    )
    try write(packageJSON(for: project), to: directoryURL.appendingPathComponent("package.json"))
    try write(readme(for: project), to: directoryURL.appendingPathComponent("README.md"))
    try write(indexHTML(for: project), to: directoryURL.appendingPathComponent("index.html"))

    if project.kind == .slideDeck {
      try write(SlideDeckScaffold.deckStageJavaScript, to: directoryURL.appendingPathComponent("deck-stage.js"))
      try write(
        SlideDeckScaffold.layoutTemplateMarkdown,
        to: directoryURL.appendingPathComponent(SlideDeckContract.templateResourcePath)
      )
    }

    writeDesignSystemBrief(for: project, at: directoryURL)
  }

  /// Provides the custom design system's spec to the project so the agent can
  /// reuse its tokens/components. Prefers the canonical, spec-compliant
  /// `DESIGN.md` authored by the design system; falls back to a derived brief
  /// only for legacy systems that predate it.
  private func writeDesignSystemBrief(for project: EaselDesignProject, at directoryURL: URL) {
    let choice = project.designSystem
    guard choice.kind == .custom, let designSystemDirectory = choice.workingDirectory else {
      return
    }

    let briefDirectory = directoryURL
      .appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
      .appendingPathComponent("design-system", isDirectory: true)
    try? fileManager.createDirectory(at: briefDirectory, withIntermediateDirectories: true)
    let destination = briefDirectory.appendingPathComponent("DESIGN.md")

    let canonicalURL = URL(fileURLWithPath: designSystemDirectory, isDirectory: true)
      .appendingPathComponent("DESIGN.md")
    if let canonical = try? Data(contentsOf: canonicalURL), !canonical.isEmpty {
      try? canonical.write(to: destination, options: .atomic)
      return
    }

    let catalog = loadDesignSystemCatalog(atDesignSystemDirectory: designSystemDirectory)
    let markdown = DesignSystemBriefBuilder.markdown(
      displayName: choice.displayName,
      detail: choice.detail,
      notes: choice.notes,
      catalog: catalog
    )
    try? Data(markdown.utf8).write(to: destination, options: .atomic)
  }

  private func loadDesignSystemCatalog(atDesignSystemDirectory directory: String) -> EaselDesignSystemCatalog? {
    let catalogURL = URL(fileURLWithPath: directory, isDirectory: true)
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("catalog.json")
    guard let data = try? Data(contentsOf: catalogURL) else { return nil }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(EaselDesignSystemCatalog.self, from: data)
  }

  private func write(_ contents: String, to url: URL) throws {
    try contents.data(using: .utf8)?.write(to: url, options: .atomic)
  }

  private func effectiveFidelity(for request: EaselProjectCreateRequest) -> EaselProjectFidelity {
    request.kind == .prototype ? request.fidelity : .highFidelity
  }

  private func normalizedProjectName(_ rawName: String, kind: EaselProjectKind) -> String {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      switch kind {
      case .prototype:
        return "Untitled Prototype"
      case .slideDeck:
        return "Untitled Slide Deck"
      }
    }
    return trimmed
  }

  private func uniqueDirectoryURL(for projectName: String) -> URL {
    let baseSlug = slug(for: projectName)
    var candidate = rootDirectory.appendingPathComponent(baseSlug, isDirectory: true)
    var suffix = 2

    while fileManager.fileExists(atPath: candidate.path) {
      candidate = rootDirectory.appendingPathComponent("\(baseSlug)-\(suffix)", isDirectory: true)
      suffix += 1
    }

    return candidate
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
    return trimmed.isEmpty ? "untitled-project" : trimmed
  }

  private func packageJSON(for project: EaselDesignProject) -> String {
    """
    {
      "name": "\(slug(for: project.name))",
      "private": true,
      "version": "0.1.0",
      "scripts": {
        "dev": "python3 -c \\"import http.server, socketserver; socketserver.TCPServer.allow_reuse_address = True; server = socketserver.TCPServer(('127.0.0.1', 0), http.server.SimpleHTTPRequestHandler); print(f'Local: http://localhost:{server.server_address[1]}', flush=True); server.serve_forever()\\""
      }
    }
    """
  }

  private func readme(for project: EaselDesignProject) -> String {
    var metadataLines = [
      "- Type: \(project.kind.displayName)",
    ]

    if project.kind == .prototype {
      metadataLines.append("- Fidelity: \(project.fidelity.displayName)")
    }

    metadataLines.append("- Design system: \(project.designSystem.displayName)")

    let designSystemGuidance = project.designSystem.kind == .custom
      ? "\nThis project uses the **\(project.designSystem.displayName)** design system. Follow `resources/design-system/DESIGN.md` for its colors, type, spacing, and component families, and reuse them throughout the UI.\n"
      : ""

    let slideDeckGuidance = project.kind == .slideDeck
      ? "\nSlide deck layout: \(SlideDeckContract.authoringSummary)\n\nReusable slide template: `\(SlideDeckContract.templateResourcePath)`\n"
      : ""

    return """
    # \(project.name)

    Created by Easel.

    \(metadataLines.joined(separator: "\n"))
    \(designSystemGuidance)
    \(slideDeckGuidance)
    Add project assets to `resources/` so Codex can inspect and use them while designing.

    Reference codebases, if present, are listed under `resources/codebase-references/`. Treat those external repositories as read-only context: inspect them only, never modify files or run commands that write inside them, and make all implementation changes inside this Easel project folder.

    Run `npm run dev` to preview this folder in Easel.
    """
  }

  private func indexHTML(for project: EaselDesignProject) -> String {
    switch project.kind {
    case .prototype:
      return prototypeIndexHTML(for: project)
    case .slideDeck:
      return SlideDeckScaffold.indexHTML(
        title: project.name,
        designSystemDisplayName: project.designSystem.displayName
      )
    }
  }

  private func prototypeIndexHTML(for project: EaselDesignProject) -> String {
    let title = escapedHTML(project.name)
    let kind = escapedHTML(project.kind.displayName)
    let fidelity = escapedHTML(project.fidelity.displayName)
    let designSystem = escapedHTML(project.designSystem.displayName)
    let accent = project.kind == .prototype ? "#2f6fed" : "#d86f51"

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
          --accent: \(accent);
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
          display: grid;
          place-items: center;
          background: var(--surface);
          color: var(--ink);
          font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }

        main {
          width: min(720px, calc(100vw - 48px));
          border: 1px solid var(--line);
          border-radius: 8px;
          background: white;
          padding: 32px;
          box-shadow: 0 16px 60px rgb(28 25 21 / 0.08);
        }

        .eyebrow {
          color: var(--accent);
          font-size: 13px;
          font-weight: 700;
          letter-spacing: 0;
          text-transform: uppercase;
        }

        h1 {
          margin: 12px 0 10px;
          font-size: clamp(34px, 6vw, 64px);
          line-height: 0.95;
          letter-spacing: 0;
        }

        p {
          margin: 0;
          color: var(--muted);
          font-size: 17px;
          line-height: 1.55;
        }

        .meta {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin-top: 28px;
        }

        .pill {
          border: 1px solid var(--line);
          border-radius: 999px;
          padding: 7px 10px;
          color: var(--muted);
          font-size: 13px;
        }
      </style>
    </head>
    <body>
      <main>
        <div class="eyebrow">Easel</div>
        <h1>\(title)</h1>
        <p>This \(kind.lowercased()) scaffold is ready for Codex to turn into a complete \(fidelity.lowercased()) experience.</p>
        <div class="meta">
          <span class="pill">\(kind)</span>
          <span class="pill">\(fidelity)</span>
          <span class="pill">\(designSystem)</span>
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
  }
}
