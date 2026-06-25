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
    // Slide deck projects get presentation-design guidance in addition to the layout contract.
    #expect(prefix.contains("For slide deck creation"))
    #expect(prefix.contains("you are a presentation designer"))
    #expect(prefix.contains("You are not building a website"))
    #expect(prefix.contains("Show the user an outline first"))
    // Animation projects get motion-design timeline guidance and starter usage.
    #expect(prefix.contains("For animation projects"))
    #expect(prefix.contains("copy_starter_component"))
    #expect(prefix.contains("resources/animations.jsx"))
    #expect(prefix.contains("uses the selected design system"))
    #expect(prefix.contains("simple, plain visual language with great taste"))
    #expect(prefix.contains("Anthropic brand palette") == false)
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
  func hiddenContextIncludesProjectResourceManifest() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/easel",
      resourcePaths: [
        "resources/hero.png",
        "resources/codebase-references/App.md",
      ],
      previewURL: nil
    )

    #expect(context.contains("Available project resources and design files"))
    #expect(context.contains("- `resources/hero.png`"))
    #expect(context.contains("- `resources/codebase-references/App.md`"))
    #expect(context.contains("Inspect these resources"))
  }

  @Test
  func resourceManifestDeltaContextIncludesAddedUpdatedAndRemovedPaths() {
    let context = EaselAgentInstructions.resourceManifestDeltaContext(
      addedPaths: ["resources/new.png"],
      updatedPaths: ["resources/design-system/DESIGN.md"],
      removedPaths: ["resources/old.png"]
    )

    #expect(context?.contains("--- Easel Resource Update ---") == true)
    #expect(context?.contains("Added resources:") == true)
    #expect(context?.contains("- `resources/new.png`") == true)
    #expect(context?.contains("Updated resources:") == true)
    #expect(context?.contains("- `resources/design-system/DESIGN.md`") == true)
    #expect(context?.contains("Removed resources:") == true)
    #expect(context?.contains("- `resources/old.png`") == true)
  }

  @Test
  func resourceManifestDeltaContextReturnsNilWhenNothingChanged() {
    let context = EaselAgentInstructions.resourceManifestDeltaContext(
      addedPaths: [],
      updatedPaths: [],
      removedPaths: []
    )

    #expect(context == nil)
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
    #expect(context.contains("The prototype fidelity contract specializes the bundled frontend skill"))
    #expect(context.contains("Prototype fidelity contract"))
    #expect(context.contains("Help the user explore design ideas quickly"))
    #expect(context.contains("show 3-5 distinctly different approaches"))
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
    #expect(context.contains("The prototype fidelity contract specializes the bundled frontend skill"))
    #expect(context.contains("Prototype fidelity contract"))
    #expect(context.contains("Create a high-fidelity, polished design"))
    #expect(context.contains("Ask 2-4 concise clarifying questions and wait"))
    #expect(context.contains("Good hi-fi designs do not start from scratch"))
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
    #expect(context.contains("Slide deck creation contract") == false)
    #expect(context.contains("Create a presentation deck as a single self-contained HTML page") == false)
    #expect(context.contains("you are a presentation designer") == false)
    #expect(context.contains("Current prototype fidelity") == false)
    #expect(context.contains("Prototype fidelity contract") == false)
  }

  @Test
  func hiddenContextIncludesAnimationContractWhenProjectIsAnimation() {
    let context = EaselAgentInstructions.hiddenContext(
      projectPath: "/tmp/animation",
      projectKind: .animation,
      previewURL: nil
    )

    #expect(context.contains("Current project type: Animation"))
    #expect(context.contains("Animation contract"))
    #expect(context.contains("Create an animated video or motion design piece"))
    #expect(context.contains("copy_starter_component"))
    #expect(context.contains("resources/animations.jsx"))
    #expect(context.contains("Stage, Sprite, PlaybackBar"))
    #expect(context.contains("uses the selected design system"))
    #expect(context.contains("simple, plain visual language with great taste"))
    #expect(context.contains("Anthropic brand palette") == false)
    #expect(context.contains("Current prototype fidelity") == false)
    #expect(context.contains("Slide deck contract") == false)
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
