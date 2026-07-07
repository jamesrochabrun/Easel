import Foundation
import XCTest
import AgentHarness
import MLXLMCommon
@testable import AgentProviderMLX

final class AgentProviderMLXTests: XCTestCase {

  // MARK: - Availability

  func testAvailabilityTiers() {
    let gb: UInt64 = 1_073_741_824
    XCTAssertFalse(MLXAvailability.check(physicalMemoryBytes: 64 * gb, isAppleSilicon: false).isSupported)
    XCTAssertEqual(
      MLXAvailability.check(physicalMemoryBytes: 8 * gb, isAppleSilicon: true).recommendedMaxTier, .small
    )
    XCTAssertEqual(
      MLXAvailability.check(physicalMemoryBytes: 16 * gb, isAppleSilicon: true).recommendedMaxTier, .medium
    )
    XCTAssertEqual(
      MLXAvailability.check(physicalMemoryBytes: 32 * gb, isAppleSilicon: true).recommendedMaxTier, .large
    )
    XCTAssertEqual(
      MLXAvailability.check(physicalMemoryBytes: 128 * gb, isAppleSilicon: true).recommendedMaxTier, .extraLarge
    )
  }

  // MARK: - Curated list

  func testCuratedModelsAreWellFormed() {
    let models = MLXCuratedModels.all
    XCTAssertFalse(models.isEmpty)
    XCTAssertEqual(Set(models.map(\.id)).count, models.count, "ids must be unique")
    XCTAssertTrue(models.allSatisfy { $0.id.contains("/") }, "ids are hub repo ids")
    XCTAssertTrue(models.allSatisfy { $0.approximateSizeBytes > 0 && $0.contextLength > 0 })

    let smallOnly = MLXCuratedModels.recommended(for: .small)
    XCTAssertTrue(smallOnly.allSatisfy { $0.minimumTier == .small })
    XCTAssertEqual(MLXCuratedModels.recommended(for: .extraLarge).count, models.count)
  }

  // MARK: - Manager

  func testManagerInstallDetectionDiskUsageAndDelete() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("mlx-manager-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = MLXModelManager(rootDirectory: root)

    let repoId = "mlx-community/Test-Model-4bit"
    let isInstalledEmpty = await manager.isInstalled(repoId: repoId)
    XCTAssertFalse(isInstalledEmpty)

    // Fake an installed layout: weights + config in the hub directory shape.
    let modelDir = await manager.directory(forRepoId: repoId)
    try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
    try Data(repeating: 7, count: 2_048).write(to: modelDir.appendingPathComponent("model.safetensors"))
    try Data("{}".utf8).write(to: modelDir.appendingPathComponent("config.json"))

    let isInstalled = await manager.isInstalled(repoId: repoId)
    XCTAssertTrue(isInstalled)

    let installed = await manager.installedModels()
    XCTAssertEqual(installed.map(\.id), [repoId])
    XCTAssertGreaterThan(installed[0].sizeBytes, 0)

    // A directory without weights (partial download) is not installed.
    let partialId = "mlx-community/Partial-Model"
    let partialDir = await manager.directory(forRepoId: partialId)
    try FileManager.default.createDirectory(at: partialDir, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: partialDir.appendingPathComponent("config.json"))
    let partialInstalled = await manager.isInstalled(repoId: partialId)
    XCTAssertFalse(partialInstalled)

    try await manager.delete(repoId: repoId)
    let afterDelete = await manager.isInstalled(repoId: repoId)
    XCTAssertFalse(afterDelete)
    XCTAssertFalse(FileManager.default.fileExists(atPath: modelDir.path))
  }

  // MARK: - Message mapping

  func testChatMappingRoundTrip() {
    let chat = MLXMessageMapper.chat(from: [
      .system("sys"),
      .user([.text("hello"), .imageDataURL("data:image/jpeg;base64,AA==")]),
      .assistant(text: "using a tool", toolCalls: [
        AgentToolCall(id: "call_1", name: "Read", arguments: #"{"file_path":"a.txt","limit":5}"#)
      ]),
      .tool(callId: "call_1", name: "Read", content: "data", isError: false),
      .tool(callId: "call_2", name: "Bash", content: "boom", isError: true),
    ])

    XCTAssertEqual(chat.count, 5)
    XCTAssertEqual(chat[0].role, .system)
    // Image blocks are dropped (vision off in v1); the text remains.
    XCTAssertEqual(chat[1].content, "hello")
    XCTAssertTrue(chat[1].images.isEmpty)

    XCTAssertEqual(chat[2].role, .assistant)
    // Tool storage is opaque; presence is asserted here and the call
    // conversion is verified directly below.
    XCTAssertNotNil(chat[2].tool)

    XCTAssertEqual(chat[3].role, .tool)
    XCTAssertEqual(chat[4].content, "[error] boom")

    let converted = MLXMessageMapper.mlxToolCall(
      AgentToolCall(id: "call_1", name: "Read", arguments: #"{"file_path":"a.txt","limit":5}"#)
    )
    XCTAssertEqual(converted.function.name, "Read")
    XCTAssertEqual(converted.id, "call_1")
    XCTAssertEqual(MLXMessageMapper.serializeArguments(converted.function.arguments), #"{"file_path":"a.txt","limit":5}"#)
  }

  func testArgumentSerializationRoundTrip() {
    let arguments = MLXMessageMapper.mlxArguments(fromJSONString: #"{"b":2,"a":"x"}"#)
    let serialized = MLXMessageMapper.serializeArguments(arguments)
    XCTAssertEqual(serialized, #"{"a":"x","b":2}"#)

    XCTAssertEqual(MLXMessageMapper.mlxArguments(fromJSONString: "not json").count, 0)
  }

  func testToolSpecShape() throws {
    let spec = MLXMessageMapper.toolSpec(
      AgentToolSchema(
        name: "Read",
        description: "reads a file",
        parameters: ["type": "object", "required": ["file_path"]]
      )
    )
    XCTAssertEqual(spec["type"] as? String, "function")
    let function = try XCTUnwrap(spec["function"] as? [String: any Sendable])
    XCTAssertEqual(function["name"] as? String, "Read")
    let parameters = try XCTUnwrap(function["parameters"] as? [String: any Sendable])
    XCTAssertEqual(parameters["type"] as? String, "object")
  }
}
