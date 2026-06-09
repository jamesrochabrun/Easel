//
//  DesignMarkdownCreationPathsTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownCreationPathsTests {

  @Test
  func resourcesPathWritesStarterDesignMarkdown() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "Nimbus: a calm weather app", source: .resources)
    )

    let directory = URL(fileURLWithPath: profile.workingDirectory)
    let designMarkdown = try String(contentsOf: directory.appendingPathComponent("DESIGN.md"), encoding: .utf8)
    #expect(designMarkdown.contains("name: Nimbus"))
    #expect(designMarkdown.contains("## Overview"))
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(".easel/catalog.json").path))
  }

  @Test
  func importMarkdownPathNormalizesFileAndDerivesCatalog() async throws {
    let root = tempRoot()
    let source = tempRoot()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: source)
    }
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let markdownURL = source.appendingPathComponent("Heritage.md")
    try Data(DesignMarkdownFixtures.heritage.utf8).write(to: markdownURL)

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "ignored", source: .designMarkdown(markdownURL))
    )

    #expect(profile.name == "Heritage")
    let directory = URL(fileURLWithPath: profile.workingDirectory)
    let designMarkdown = try String(contentsOf: directory.appendingPathComponent("DESIGN.md"), encoding: .utf8)
    #expect(designMarkdown.hasPrefix("---\nversion: alpha"))
    #expect(designMarkdown.contains("name: Heritage"))
    // Original kept for provenance.
    #expect(FileManager.default.fileExists(
      atPath: directory.appendingPathComponent("resources/design-system/Heritage.md").path
    ))
    // catalog.json derived from the canonical DESIGN.md (author's names preserved).
    let catalog = try await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory)
    #expect(catalog?.tokens?.colors.first?.name == "primary")
  }

  @Test
  func pastedMarkdownPathNormalizesAndDerivesCatalog() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "ignored", source: .designMarkdownText(DesignMarkdownFixtures.heritage))
    )

    #expect(profile.name == "Heritage")
    let directory = URL(fileURLWithPath: profile.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("DESIGN.md").path))
    // Pasted text is retained for provenance.
    #expect(FileManager.default.fileExists(
      atPath: directory.appendingPathComponent("resources/design-system/DESIGN.md").path
    ))
    let catalog = try await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory)
    #expect(catalog?.tokens?.colors.first?.name == "primary")
  }

  @Test
  func explicitNameOverridesImportedDocumentName() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(from: EaselDesignSystemCreateRequest(
      blurb: "",
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: "",
      source: .designMarkdownText(DesignMarkdownFixtures.heritage),
      nameHint: "My Editorial Kit"
    ))

    #expect(profile.name == "My Editorial Kit")
    let directory = URL(fileURLWithPath: profile.workingDirectory)
    let designMarkdown = try String(contentsOf: directory.appendingPathComponent("DESIGN.md"), encoding: .utf8)
    // The chosen name is written back into the canonical DESIGN.md.
    #expect(designMarkdown.contains("name: My Editorial Kit"))
  }

  @Test
  func importMarkdownRepairsMissingFrontMatter() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let prose = [
      "# Brandless",
      "",
      "A simple kit.",
      "",
      "## Colors",
      "- Primary #112233",
    ].joined(separator: "\n")

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "", source: .designMarkdownText(prose))
    )

    let directory = URL(fileURLWithPath: profile.workingDirectory)
    let designMarkdown = try String(contentsOf: directory.appendingPathComponent("DESIGN.md"), encoding: .utf8)
    #expect(designMarkdown.hasPrefix("---\nversion: alpha"))
    #expect(designMarkdown.contains("name: Brandless"))
    #expect(designMarkdown.contains("primary: \"#112233\""))

    // The auto-fix is surfaced as a diagnostic.
    let catalog = try await manager.loadCatalog(forDesignSystemAt: profile.workingDirectory)
    #expect(catalog?.sourceDiagnostics?.warnings.contains { $0.contains("front matter was missing") } == true)
  }

  @Test
  func importMarkdownPathRejectsBrokenReferences() async throws {
    let root = tempRoot()
    let source = tempRoot()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: source)
    }
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let markdownURL = source.appendingPathComponent("Imperfect.md")
    try Data(DesignMarkdownFixtures.imperfect.utf8).write(to: markdownURL)

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    await #expect(throws: DesignMarkdownLintError.self) {
      _ = try await manager.createDesignSystem(
        from: request(blurb: "ignored", source: .designMarkdown(markdownURL))
      )
    }
  }

  @Test
  func regenerateFromImportedDesignMarkdownRebuildsCatalog() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "", source: .designMarkdownText(DesignMarkdownFixtures.heritage))
    )

    // No .fig sources, but Regenerate rebuilds from the canonical DESIGN.md.
    let result = try await manager.regenerateDesignSystem(forDesignSystemAt: profile.workingDirectory)
    let catalog = try #require(result.catalog)
    #expect(catalog.tokens?.colors.first?.name == "primary")
    #expect(catalog.componentFamilies?.isEmpty == false)
    #expect(catalog.componentFamilies?.first?.preview != nil)
  }

  @Test
  func promptPathUsesGeneratorAndWritesArtifacts() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(
      rootDirectory: root,
      importScheduling: .immediate,
      designMarkdownGenerator: StubDesignMarkdownGenerator(markdown: DesignMarkdownFixtures.heritage)
    )
    let profile = try await manager.createDesignSystem(
      from: request(blurb: "a premium editorial brand", source: .prompt("a premium editorial brand"))
    )

    #expect(profile.name == "Heritage")
    let directory = URL(fileURLWithPath: profile.workingDirectory)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("DESIGN.md").path))
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(".easel/catalog.json").path))
  }

  @Test
  func promptPathWithoutGeneratorThrows() async throws {
    let root = tempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = LocalEaselDesignSystemManager(rootDirectory: root, importScheduling: .immediate)
    await #expect(throws: EaselDesignSystemManagerError.designMarkdownGenerationUnavailable) {
      _ = try await manager.createDesignSystem(from: request(blurb: "x", source: .prompt("x")))
    }
  }

  // MARK: - Helpers

  private func request(blurb: String, source: EaselDesignSystemCreateRequest.Source) -> EaselDesignSystemCreateRequest {
    EaselDesignSystemCreateRequest(
      blurb: blurb,
      sourceLinks: [],
      codeSourceURLs: [],
      figFileURLs: [],
      assetURLs: [],
      notes: "",
      source: source
    )
  }

  private func tempRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("DSPaths-\(UUID().uuidString)", isDirectory: true)
  }
}

private struct StubDesignMarkdownGenerator: DesignMarkdownGenerating {
  let markdown: String
  func generateDesignMarkdown(prompt: String, name: String?) async throws -> String { markdown }
}
