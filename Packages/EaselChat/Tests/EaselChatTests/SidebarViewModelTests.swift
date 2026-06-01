//
//  SidebarViewModelTests.swift
//  EaselChatTests
//

import ClaudeCodeCore
import Foundation
import Testing
@testable import EaselChat

@MainActor
struct SidebarViewModelTests {

  @Test
  func creatingProjectLaunchesEmptyConversation() async {
    let project = EaselDesignProject(
      id: UUID(),
      name: "Manhattan",
      kind: .prototype,
      designSystem: .none,
      fidelity: .wireframe,
      workingDirectory: "/tmp/manhattan",
      createdAt: Date(),
      updatedAt: Date()
    )
    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      projectManager: SidebarProjectManagerStub(project: project)
    )
    viewModel.projectName = "Manhattan"

    var launchedProject: EaselProjectLaunch?
    viewModel.onProjectLaunchRequested = { launch in
      launchedProject = launch
    }

    await viewModel.createProjectAndStartSession(seedPrompt: "Create a Manhattan planning dashboard")

    #expect(launchedProject?.project == project)
    #expect(launchedProject?.prompt == "")
  }
}

private actor SidebarProjectManagerStub: EaselProjectManaging {
  private let project: EaselDesignProject

  init(project: EaselDesignProject) {
    self.project = project
  }

  func loadProjects() async throws -> [EaselDesignProject] {
    [project]
  }

  func createProject(from request: EaselProjectCreateRequest) async throws -> EaselDesignProject {
    project
  }
}
