import Foundation
import XCTest
import AgentHarness
@testable import AgentProviderMLX

/// Real-inference verification that a downloaded MLX model can emit tool
/// calls. Skipped by default (loads the model + runs generation); enable with:
///
///   EASEL_MLX_INTEGRATION=1 EASEL_MLX_MODEL="mlx-community/Qwen2.5-Coder-7B-Instruct-4bit" \
///   swift test --filter MLXToolCallIntegrationTests
///
/// Uses the app's real model directory so a model downloaded in Easel is
/// exercised as-is.
final class MLXToolCallIntegrationTests: XCTestCase {

  func testInstalledModelEmitsToolCall() async throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["EASEL_MLX_INTEGRATION"] == "1",
      "Set EASEL_MLX_INTEGRATION=1 to run on-device MLX inference."
    )
    let repoId = ProcessInfo.processInfo.environment["EASEL_MLX_MODEL"]
      ?? "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"

    let manager = MLXModelManager()
    let installed = await manager.isInstalled(repoId: repoId)
    try XCTSkipUnless(installed, "\(repoId) is not downloaded.")

    let runtime = MLXModelRuntime(manager: manager)
    var profile = EndpointProfile.builtInPresets().first { $0.kind == .mlxLocal }!
    profile.defaultModel = repoId
    let client = MLXModelClient(profile: profile, runtime: runtime, manager: manager)

    let request = AgentModelRequest(
      model: repoId,
      messages: [
        .system("You are a coding agent. Use the provided tools to act. Do not answer in prose when a tool applies."),
        .user([.text("List the files in the project directory.")]),
      ],
      tools: [
        AgentToolSchema(
          name: "LS",
          description: "Lists the files in a directory of the project.",
          parameters: ["type": "object", "properties": ["path": ["type": "string"]]]
        )
      ],
      maxOutputTokens: 256,
      stream: true
    )

    var text = ""
    var toolCalls: [String] = []
    for try await event in try await client.streamCompletion(request) {
      switch event {
      case .textDelta(let delta): text += delta
      case .toolCallDelta(_, _, let name, let args):
        toolCalls.append("\(name ?? "?")(\(args))")
      default: break
      }
    }

    print("=== MLX tool-call verification: \(repoId) ===")
    print("structured tool calls: \(toolCalls)")
    print("assistant text: \(text)")

    XCTAssertFalse(
      toolCalls.isEmpty,
      "Model produced no structured tool call. Text was: \(text)"
    )
    XCTAssertTrue(toolCalls.contains { $0.hasPrefix("LS") }, "Expected an LS tool call, got \(toolCalls)")
  }
}
