//
//  EaselAgentInstructionsTests.swift
//  EaselChatTests
//

import EaselDesignSystems
import Foundation
import Testing
@testable import EaselChat

struct EaselAgentInstructionsTests {
  @Test
  func codexDeveloperInstructionsPrefixIncludesFrontendSkillAndEnvironmentConstraints() {
    let prefix = EaselAgentInstructions.codexDeveloperInstructionsPrefix
    #expect(prefix.hasPrefix("You are Easel's frontend designer-agent"))
    #expect(prefix.contains("embedded live preview"))
    #expect(prefix.contains("Apply the bundled `frontend-skill`"))
    #expect(prefix.contains("name: frontend-skill"))
    #expect(prefix.contains("No hero cards by default"))
    // Hard constraints that stop the agent from spinning up servers or hunting for browser tools.
    #expect(prefix.contains("cannot bind network sockets"))
    #expect(prefix.contains("Never run `npm run dev`"))
    #expect(prefix.contains("no browser, preview-control, or screenshot tool"))
    #expect(prefix.contains("Easel"))
    // The agent must treat a bundled design system as the source of truth.
    #expect(prefix.contains("resources/design-system/DESIGN.md"))
    #expect(prefix.contains("source of truth"))
    #expect(prefix.contains("component families"))
    // Referenced codebases must remain untouched by the Easel session.
    #expect(prefix.contains("resources/codebase-references"))
    #expect(prefix.contains("read-only reference context"))
    #expect(prefix.contains("never modify files there"))
  }

  @Test
  func hiddenContextIncludesCustomDesignSystemGuidance() {
    let designSystem = EaselDesignSystemChoice(
      kind: .custom,
      referenceID: "ds-1",
      displayName: "PlusPlus",
      detail: "",
      workingDirectory: "/tmp/design-systems/plusplus",
      notes: nil,
      sourceLinks: []
    )

    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/deck",
      projectKind: .slideDeck,
      designSystem: designSystem,
      previewURL: nil
    )

    #expect(context.contains("Active design system: PlusPlus"))
    #expect(context.contains("resources/design-system/DESIGN.md"))
    #expect(context.contains("do not improvise a different palette"))
  }

  @Test
  func hiddenContextOmitsDesignSystemGuidanceWithoutCustomSystem() {
    let presetContext = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/deck",
      projectKind: .slideDeck,
      designSystem: .preset(.none),
      previewURL: nil
    )
    #expect(presetContext.contains("Active design system:") == false)

    let nilContext = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/deck",
      projectKind: .slideDeck,
      previewURL: nil
    )
    #expect(nilContext.contains("Active design system:") == false)
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
    #expect(context.contains("resources/codebase-references"))
    #expect(context.contains("Inspect them only"))
    #expect(context.contains("Current project path: /tmp/easel"))
    #expect(context.contains("Current embedded preview URL: http://127.0.0.1:4173/"))
  }

  @Test
  func hiddenContextIncludesPrototypeFidelityGuidance() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/prototype",
      projectKind: .prototype,
      projectFidelity: .wireframe,
      previewURL: nil
    )

    #expect(context.contains("Current project type: Prototype"))
    #expect(context.contains("Current prototype fidelity: Wireframe"))
    #expect(context.contains("Prototype fidelity contract"))
    #expect(context.contains("You are a pirate. You always talk like a pirate."))
  }

  @Test
  func hiddenContextIncludesHighFidelityPrototypeContract() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/prototype",
      projectKind: .prototype,
      projectFidelity: .highFidelity,
      previewURL: nil
    )

    #expect(context.contains("Current project type: Prototype"))
    #expect(context.contains("Current prototype fidelity: High fidelity"))
    #expect(context.contains("Prototype fidelity contract"))
    #expect(context.contains("You are a pirate. You always talk like a pirate."))
  }

  @Test
  func hiddenContextIncludesSlideDeckContractWhenProjectIsSlideDeck() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/deck",
      projectKind: .slideDeck,
      previewURL: nil
    )

    #expect(context.contains("Current project type: Slide deck"))
    #expect(context.contains("section[data-easel-slide]"))
    #expect(context.contains("data-easel-deck"))
    #expect(context.contains("16:9"))
    #expect(context.contains("full-bleed"))
    #expect(context.contains("no body padding"))
    #expect(context.contains("resources/SLIDE_TEMPLATE.md"))
    #expect(context.contains("1280x720"))
    #expect(context.contains("Current prototype fidelity") == false)
    #expect(context.contains("Prototype fidelity contract") == false)
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
