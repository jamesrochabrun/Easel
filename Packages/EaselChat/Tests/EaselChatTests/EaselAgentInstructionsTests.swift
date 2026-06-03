//
//  EaselAgentInstructionsTests.swift
//  EaselChatTests
//

import Foundation
import Testing
@testable import EaselChat

struct EaselAgentInstructionsTests {
  @Test
  func codexDeveloperInstructionsPrefixIncludesFrontendSkillAndEnvironmentConstraints() {
    let prefix = EaselAgentInstructions.codexDeveloperInstructionsPrefix
    #expect(prefix.hasPrefix("You are Codex Design's frontend designer-agent"))
    #expect(prefix.contains("embedded live preview"))
    #expect(prefix.contains("Apply the bundled `frontend-skill`"))
    #expect(prefix.contains("name: frontend-skill"))
    #expect(prefix.contains("No hero cards by default"))
    // Hard constraints that stop the agent from spinning up servers or hunting for browser tools.
    #expect(prefix.contains("cannot bind network sockets"))
    #expect(prefix.contains("Never run `npm run dev`"))
    #expect(prefix.contains("no browser, preview-control, or screenshot tool"))
    #expect(prefix.contains("Codex Design"))
  }

  @Test
  func hiddenContextIncludesPreviewGuidance() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/easel",
      previewURL: URL(string: "http://127.0.0.1:4173/")!
    )

    #expect(context.contains("right-side Canvas panel"))
    #expect(context.contains("hard-reloads it automatically"))
    #expect(context.contains("Do not launch an external browser app"))
    #expect(context.contains("cannot bind network sockets"))
    #expect(context.contains("resources/ folder"))
    #expect(context.contains("Current project path: /tmp/easel"))
    #expect(context.contains("Current embedded preview URL: http://127.0.0.1:4173/"))
  }

  @Test
  func appendsExistingHiddenContext() {
    let context = EaselAgentInstructions.appendingHiddenContext(
      "Currently viewing: /tmp/easel/index.html",
      projectPath: "/tmp/easel",
      previewURL: nil
    )

    #expect(context.hasPrefix("Currently viewing: /tmp/easel/index.html"))
    #expect(context.contains("The right-side Canvas panel is the preview surface"))
  }
}
