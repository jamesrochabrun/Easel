//
//  CodexModelCacheCatalogTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class CodexModelCacheCatalogTests: XCTestCase {
  private enum TestError: Error {
    case failed
  }

  func testVisibleModelsAreSortedByPriorityAndHiddenModelsAreExcluded() throws {
    let json = """
    {
      "models": [
        {
          "slug": "hidden-model",
          "display_name": "Hidden Model",
          "visibility": "hide",
          "priority": 1
        },
        {
          "slug": "gpt-fast",
          "display_name": "GPT Fast",
          "description": "Fast model",
          "visibility": "list",
          "priority": 20
        },
        {
          "slug": "gpt-strong",
          "display_name": "GPT Strong",
          "description": "Strong model",
          "visibility": "list",
          "priority": 10
        }
      ]
    }
    """

    let models = try CodexModelCacheCatalog.visibleModels(from: Data(json.utf8))

    XCTAssertEqual(models.map(\.slug), ["gpt-strong", "gpt-fast"])
    XCTAssertEqual(models.first?.description, "Strong model")
  }

  func testMissingVisibilityDefaultsToVisible() throws {
    let json = """
    {
      "models": [
        {
          "slug": "gpt-default-visible",
          "display_name": "GPT Default Visible"
        }
      ]
    }
    """

    let models = try CodexModelCacheCatalog.visibleModels(from: Data(json.utf8))

    XCTAssertEqual(models.map(\.slug), ["gpt-default-visible"])
  }

  func testConfiguredModelIdentifierReadsTopLevelModelOnly() {
    let config = """
    # model = "ignored"
    model = "gpt-5.4"

    [profiles.auto]
    model = "profile-model"
    """

    XCTAssertEqual(CodexModelCacheCatalog.configuredModelIdentifier(in: config), "gpt-5.4")
  }

  func testConfiguredModelIdentifierIgnoresProfileModelWithoutTopLevelModel() {
    let config = """
    [profiles.auto]
    model = "profile-model"
    """

    XCTAssertNil(CodexModelCacheCatalog.configuredModelIdentifier(in: config))
  }

  func testDefaultModelIdentifierPrefersCodexConfig() throws {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: homeDirectory) }

    try """
    model = "gpt-configured"
    """.write(
      to: codexDirectory.appendingPathComponent("config.toml"),
      atomically: true,
      encoding: .utf8
    )

    let catalog = CodexModelCacheCatalog()

    XCTAssertEqual(catalog.defaultModelIdentifier(homeDirectory: homeDirectory.path), "gpt-configured")
  }

  func testAvailableModelsUsesDebugModelsCommandBeforeCache() async throws {
    let homeDirectory = try makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectory) }

    try writeCachedModels(
      """
      {
        "models": [
          {
            "slug": "cached-model",
            "display_name": "Cached Model",
            "visibility": "list",
            "priority": 1
          }
        ]
      }
      """,
      homeDirectory: homeDirectory
    )

    let debugJSON = Data("""
    {
      "models": [
        {
          "slug": "debug-model",
          "display_name": "Debug Model",
          "visibility": "list",
          "priority": 1
        }
      ]
    }
    """.utf8)

    let catalog = CodexModelCacheCatalog(
      debugModelsCommandRunner: StubDebugModelsCommandRunner(result: .success(debugJSON))
    )

    let models = await catalog.availableModels(homeDirectory: homeDirectory.path)

    XCTAssertEqual(models.map(\.slug), ["debug-model"])
  }

  func testAvailableModelsFallsBackToModelsCacheWhenDebugCommandFails() async throws {
    let homeDirectory = try makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectory) }

    try writeCachedModels(
      """
      {
        "models": [
          {
            "slug": "cached-model",
            "display_name": "Cached Model",
            "visibility": "list",
            "priority": 1
          }
        ]
      }
      """,
      homeDirectory: homeDirectory
    )

    let catalog = CodexModelCacheCatalog(
      debugModelsCommandRunner: StubDebugModelsCommandRunner(result: .failure(TestError.failed))
    )

    let models = await catalog.availableModels(homeDirectory: homeDirectory.path)

    XCTAssertEqual(models.map(\.slug), ["cached-model"])
  }

  private func makeHomeDirectory() throws -> URL {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
    return homeDirectory
  }

  private func writeCachedModels(_ json: String, homeDirectory: URL) throws {
    let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
    try json.write(
      to: codexDirectory.appendingPathComponent("models_cache.json"),
      atomically: true,
      encoding: .utf8
    )
  }
}

private struct StubDebugModelsCommandRunner: CodexDebugModelsCommandRunning {
  let result: Result<Data, Error>

  func debugModelsJSON(homeDirectory: String) async throws -> Data {
    try result.get()
  }
}
