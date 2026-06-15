//
//  LocalAgentHandoffViewModelTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import XCTest
@testable import EaselChat

@MainActor
final class LocalAgentHandoffViewModelTests: XCTestCase {
  func testTargetsHideCodebaseWhenNoCodebaseWasProvided() {
    XCTAssertEqual(
      LocalAgentHandoffTarget.availableTargets(hasCodebase: false),
      [.selectedRepository, .newProject]
    )
  }

  func testTargetsIncludeCodebaseWhenCodebaseWasProvided() {
    XCTAssertEqual(
      LocalAgentHandoffTarget.availableTargets(hasCodebase: true),
      [.codebase, .selectedRepository, .newProject]
    )
  }

  func testCodexLaunchBuildsRequestFromContext() async {
    let launcher = RecordingLocalAgentLauncher()
    let viewModel = LocalAgentHandoffViewModel(
      launcher: launcher,
      workspaceCreator: FixedLocalAgentWorkspaceCreator(path: "/tmp/new-project")
    )
    viewModel.selectedProvider = .codex
    viewModel.selectedTarget = .codebase
    viewModel.details = "implement the selected screen"

    await viewModel.launch(context: context())

    let requests = await launcher.recordedRequests()
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(requests[0].provider, .codex)
    XCTAssertEqual(requests[0].workingDirectory, "/tmp/private-codebase")
    XCTAssertEqual(requests[0].command, "codex-custom")
    XCTAssertEqual(requests[0].codexModel, "gpt-5.5")
    XCTAssertEqual(requests[0].extraArguments, ["--api-mode", "enterprise"])
    XCTAssertEqual(requests[0].environment, ["EASEL_ENV": "1"])
    XCTAssertTrue(requests[0].prompt.contains("Implement: implement the selected screen"))
    XCTAssertEqual(viewModel.successMessage, "Started Codex in Terminal.")
    XCTAssertNil(viewModel.errorMessage)
  }

  func testClaudeLaunchBuildsRequestFromContext() async {
    let launcher = RecordingLocalAgentLauncher()
    let viewModel = LocalAgentHandoffViewModel(
      launcher: launcher,
      workspaceCreator: FixedLocalAgentWorkspaceCreator(path: "/tmp/new-project")
    )
    viewModel.selectedProvider = .claude
    viewModel.selectRepository(URL(fileURLWithPath: "/tmp/selected-repo"))

    await viewModel.launch(context: context())

    let requests = await launcher.recordedRequests()
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(requests[0].provider, .claude)
    XCTAssertEqual(requests[0].workingDirectory, "/tmp/selected-repo")
    XCTAssertEqual(requests[0].command, "claude-custom")
    XCTAssertEqual(requests[0].additionalPaths, ["/custom/claude"])
    XCTAssertNil(requests[0].codexModel)
    XCTAssertTrue(requests[0].extraArguments.isEmpty)
  }

  func testLaunchFailureSetsErrorMessage() async {
    let viewModel = LocalAgentHandoffViewModel(
      launcher: FailingLocalAgentLauncher(),
      workspaceCreator: FixedLocalAgentWorkspaceCreator(path: "/tmp/new-project")
    )
    viewModel.selectedTarget = .codebase

    await viewModel.launch(context: context())

    XCTAssertEqual(viewModel.errorMessage, LocalAgentLaunchError.terminalOpenFailed.localizedDescription)
    XCTAssertNil(viewModel.successMessage)
  }

  func testCreateProjectTargetCreatesWorkingDirectory() async {
    let launcher = RecordingLocalAgentLauncher()
    let viewModel = LocalAgentHandoffViewModel(
      launcher: launcher,
      workspaceCreator: FixedLocalAgentWorkspaceCreator(path: "/tmp/new-project")
    )
    viewModel.selectedTarget = .newProject

    XCTAssertFalse(viewModel.canLaunch(context: context()))
    XCTAssertTrue(viewModel.canCreateProject(context: context()))

    await viewModel.createProject(context: context(), in: URL(fileURLWithPath: "/tmp/root"))

    XCTAssertEqual(viewModel.createdProjectPath, "/tmp/new-project")
    XCTAssertTrue(viewModel.canLaunch(context: context()))
    XCTAssertFalse(viewModel.canCreateProject(context: context()))

    await viewModel.launch(context: context())

    let requests = await launcher.recordedRequests()
    XCTAssertEqual(requests.first?.workingDirectory, "/tmp/new-project")
  }

  private func context() -> LocalAgentHandoffContext {
    LocalAgentHandoffContext(
      easelProjectPath: "/tmp/easel-project",
      codebasePath: "/tmp/private-codebase",
      project: nil,
      previewURL: nil,
      claudeCommand: "claude-custom",
      claudeAdditionalPaths: ["/custom/claude"],
      codexCommand: "codex-custom",
      codexModel: "gpt-5.5",
      codexExtraArgs: "--api-mode enterprise",
      codexEnvironmentVariables: ["EASEL_ENV": "1"]
    )
  }
}

private actor RecordingLocalAgentLauncher: LocalAgentLaunching {
  private var requests: [LocalAgentLaunchRequest] = []

  func launch(_ request: LocalAgentLaunchRequest) async throws {
    requests.append(request)
  }

  func recordedRequests() -> [LocalAgentLaunchRequest] {
    requests
  }
}

private struct FailingLocalAgentLauncher: LocalAgentLaunching {
  func launch(_ request: LocalAgentLaunchRequest) async throws {
    throw LocalAgentLaunchError.terminalOpenFailed
  }
}

private struct FixedLocalAgentWorkspaceCreator: LocalAgentHandoffWorkspaceCreating {
  let path: String

  func createWorkspace(for context: LocalAgentHandoffContext, in parentDirectory: URL) async throws -> String {
    XCTAssertEqual(parentDirectory.path, "/tmp/root")
    return path
  }
}
