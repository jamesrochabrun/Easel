//
//  ClaudeModelCatalogTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class ClaudeModelCatalogTests: XCTestCase {
  func testAcceptsVersionedClaudeIdsAndRejectsNoise() {
    XCTAssertTrue(ClaudeModelCatalog.isValidModelIdentifier("claude-opus-4-8"))
    XCTAssertTrue(ClaudeModelCatalog.isValidModelIdentifier("claude-haiku-4-5-20251001"))

    XCTAssertFalse(ClaudeModelCatalog.isValidModelIdentifier("Claude Opus 4.8"))
    XCTAssertFalse(ClaudeModelCatalog.isValidModelIdentifier("claude-opus-4-8[1m]"))
    XCTAssertFalse(ClaudeModelCatalog.isValidModelIdentifier("gpt-5.5"))
    XCTAssertFalse(ClaudeModelCatalog.isValidModelIdentifier("opus"))
  }

  func testExtractsEveryModelValueFromLine() {
    let line = #"{"type":"assistant","message":{"model":"claude-opus-4-8","other":"x"},"model":"claude-haiku-4-5"}"#

    XCTAssertEqual(
      ClaudeModelCatalog.modelValues(inLine: line),
      ["claude-opus-4-8", "claude-haiku-4-5"]
    )
  }

  func testCollectsDistinctValidIdsFromJSONLDocument() {
    let jsonl = """
    {"type":"user","message":{"role":"user"}}
    {"type":"assistant","message":{"model":"claude-opus-4-8"}}
    {"type":"assistant","message":{"model":"claude-opus-4-8"}}
    {"type":"assistant","message":{"model":"claude-opus-4-7"}}
    {"summary":"Claude Opus 4.8 did things"}
    {"type":"assistant","message":{"model":"gpt-5.5"}}
    """

    let ids = ClaudeModelCatalog.modelIdentifiers(inJSONL: jsonl)

    XCTAssertEqual(ids, ["claude-opus-4-8", "claude-opus-4-7"])
  }

  func testDiscoversIdentifiersByRecency() throws {
    let directory = try makeTempProjects()
    defer { try? FileManager.default.removeItem(at: directory) }

    try writeSession(
      named: "old.jsonl",
      model: "claude-opus-4-7",
      modified: Date(timeIntervalSince1970: 1_000),
      in: directory
    )
    try writeSession(
      named: "new.jsonl",
      model: "claude-opus-4-8",
      modified: Date(timeIntervalSince1970: 2_000),
      in: directory
    )

    let ids = ClaudeModelCatalog.discoverModelIdentifiers(inProjectsDirectory: directory)

    XCTAssertEqual(ids, ["claude-opus-4-8", "claude-opus-4-7"])
  }

  func testAvailableModelsListsAliasesFirstThenDiscoveredVersionedIds() async throws {
    let directory = try makeTempProjects()
    defer { try? FileManager.default.removeItem(at: directory) }
    try writeSession(
      named: "session.jsonl",
      model: "claude-opus-4-8",
      modified: Date(timeIntervalSince1970: 2_000),
      in: directory
    )

    let catalog = ClaudeModelCatalog(projectsDirectory: directory)
    let options = await catalog.availableModels()

    XCTAssertEqual(options.prefix(3).map(\.identifier), ["opus", "sonnet", "haiku"])
    XCTAssertTrue(options.map(\.identifier).contains("claude-opus-4-8"))
    XCTAssertEqual(options.first { $0.identifier == "claude-opus-4-8" }?.detail, "Used in your sessions")
  }

  private func makeTempProjects() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("claude_catalog_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func writeSession(named name: String, model: String, modified: Date, in directory: URL) throws {
    let url = directory.appendingPathComponent(name)
    let line = #"{"type":"assistant","message":{"model":"\#(model)"}}"# + "\n"
    try line.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
  }
}
