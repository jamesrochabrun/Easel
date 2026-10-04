//
//  ArnesModelCatalogTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class ArnesModelCatalogTests: XCTestCase {
  func testParsesManifestPinsAutoFirstAndFiltersToollessModels() async {
    let json = """
    [
      {"id":"zeta/no-tools","supports_tools":false,"context_length":32000},
      {"id":"anthropic/claude-sonnet-4.5","supports_tools":true,"supports_reasoning":true,
       "supports_vision":true,"context_length":1000000,
       "prompt_price_per_token":3e-06,"completion_price_per_token":1.5e-05},
      {"id":"anthropic/claude-sonnet-4.5:batch","supports_tools":true,"context_length":1000000},
      {"id":"deepseek/deepseek-v4-flash","supports_tools":true,"context_length":262144,
       "prompt_price_per_token":0,"completion_price_per_token":0}
    ]
    """
    let catalog = ArnesModelCatalog(commandRunner: FixtureRunner(json: json))

    let models = await catalog.availableModels()

    XCTAssertEqual(models.first?.identifier, ArnesModelDescriptor.autoIdentifier)
    XCTAssertEqual(
      models.map(\.identifier),
      ["openrouter/auto", "anthropic/claude-sonnet-4.5", "deepseek/deepseek-v4-flash"]
    )

    let sonnet = models[1]
    XCTAssertTrue(sonnet.supportsReasoning)
    XCTAssertTrue(sonnet.supportsVision)
    XCTAssertEqual(sonnet.contextLength, 1_000_000)
    XCTAssertEqual(sonnet.detail, "1M ctx · $3/15 per M tokens · reasoning · vision")

    let deepseek = models[2]
    XCTAssertEqual(deepseek.detail, "262K ctx · free")
  }

  func testFailedCommandStillOffersAuto() async {
    let catalog = ArnesModelCatalog(commandRunner: FailingRunner())

    let models = await catalog.availableModels()

    XCTAssertEqual(models.map(\.identifier), [ArnesModelDescriptor.autoIdentifier])
  }

  func testMalformedJSONStillOffersAuto() {
    let models = ArnesModelCatalog.descriptors(fromModelsJSON: Data("not json".utf8))
    XCTAssertEqual(models.map(\.identifier), [ArnesModelDescriptor.autoIdentifier])
  }

  func testDefaultModelIsAuto() {
    XCTAssertEqual(ArnesModelCatalog().defaultModelIdentifier(), "openrouter/auto")
  }
}

private struct FixtureRunner: ArnesModelsCommandRunning {
  let json: String

  func modelsJSON() async throws -> Data {
    Data(json.utf8)
  }
}

private struct FailingRunner: ArnesModelsCommandRunning {
  func modelsJSON() async throws -> Data {
    throw ArnesCommandError.executableNotFound
  }
}
