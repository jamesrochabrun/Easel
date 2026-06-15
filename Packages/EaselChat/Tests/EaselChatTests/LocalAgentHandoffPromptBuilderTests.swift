//
//  LocalAgentHandoffPromptBuilderTests.swift
//  EaselChatTests
//

import Foundation
import XCTest
@testable import EaselChat
import EaselDesignSystems

final class LocalAgentHandoffPromptBuilderTests: XCTestCase {
  func testPromptReferencesLocalProjectFilesAndDetails() {
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: "polish the onboarding flow",
      context: context(project: prototypeProject())
    )

    XCTAssertTrue(prompt.contains("Implement in the current terminal working directory"))
    XCTAssertTrue(prompt.contains("Easel resources path: /tmp/easel-project"))
    XCTAssertTrue(prompt.contains("Read `/tmp/easel-project/README.md`"))
    XCTAssertTrue(prompt.contains("Inspect `/tmp/easel-project/resources/`"))
    XCTAssertTrue(prompt.contains("/tmp/easel-project/resources/design-system/DESIGN.md"))
    XCTAssertTrue(prompt.contains("Implement: polish the onboarding flow"))
  }

  func testPromptDoesNotExposeCodebasePath() {
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: "polish the onboarding flow",
      context: context(project: prototypeProject())
    )

    XCTAssertFalse(prompt.contains("/tmp/private-codebase"))
  }

  func testPromptUsesDefaultDetailsWhenBlank() {
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: "  ",
      context: context(project: prototypeProject())
    )

    XCTAssertTrue(prompt.contains("Implement: the designs in this project"))
  }

  func testPrototypePromptIncludesFidelityAndDesignSystemContext() {
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: "ship it",
      context: context(project: prototypeProject())
    )

    XCTAssertTrue(prompt.contains("Current project type: Prototype"))
    XCTAssertTrue(prompt.contains("Current prototype fidelity: High fidelity"))
    XCTAssertTrue(prompt.contains("Active design system: Studio System"))
  }

  func testSlideDeckPromptIncludesSlideContract() {
    let prompt = LocalAgentHandoffPromptBuilder.prompt(
      details: "update the deck",
      context: context(project: slideDeckProject())
    )

    XCTAssertTrue(prompt.contains("Current project type: Slide deck"))
    XCTAssertTrue(prompt.contains("Slide deck contract:"))
  }

  private func context(project: EaselDesignProject?) -> LocalAgentHandoffContext {
    LocalAgentHandoffContext(
      easelProjectPath: "/tmp/easel-project",
      codebasePath: "/tmp/private-codebase",
      project: project,
      previewURL: URL(string: "http://localhost:4321"),
      claudeCommand: "claude",
      claudeAdditionalPaths: [],
      codexCommand: "",
      codexModel: "gpt-5.5",
      codexExtraArgs: "",
      codexEnvironmentVariables: [:]
    )
  }

  private func prototypeProject() -> EaselDesignProject {
    EaselDesignProject(
      id: UUID(),
      name: "Prototype",
      kind: .prototype,
      designSystem: customDesignSystem(),
      fidelity: .highFidelity,
      workingDirectory: "/tmp/easel-project",
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0)
    )
  }

  private func slideDeckProject() -> EaselDesignProject {
    EaselDesignProject(
      id: UUID(),
      name: "Deck",
      kind: .slideDeck,
      designSystem: .preset(.none),
      fidelity: .highFidelity,
      workingDirectory: "/tmp/easel-project",
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0)
    )
  }

  private func customDesignSystem() -> EaselDesignSystemChoice {
    EaselDesignSystemChoice(
      kind: .custom,
      referenceID: UUID().uuidString,
      displayName: "Studio System",
      detail: "A local system",
      workingDirectory: "/tmp/studio-system",
      notes: nil,
      sourceLinks: []
    )
  }
}
