//
//  ChatServiceTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

@MainActor
struct ChatServiceTests {

  @Test
  func initialState() {
    let service = ChatService()
    #expect(service.chatViewModel == nil)
    #expect(service.isInitialized == false)
    #expect(service.initError == nil)
    #expect(service.previewURL == nil)
  }

  @Test
  func sendMessageWithoutInitializationIsNoOp() {
    let service = ChatService()
    // Should not crash when chatViewModel is nil
    service.sendMessage("test")
    service.sendInspectorPrompt("test")
    service.sendContextPrompt("test")
    service.sendCropPrompt("test")
  }

  @Test
  func appManagedPreviewURLIgnoresDetectedReplacementURL() {
    let service = ChatService()
    service.setPreviewURL(URL(string: "http://localhost:4301/")!)

    service.applyDetectedPreviewURL(URL(string: "http://127.0.0.1:5173/")!)

    #expect(service.previewURL?.absoluteString == "http://localhost:4301/")
  }

  @Test
  func detectedPreviewURLAppliesWhenNoManagedURLExists() {
    let service = ChatService()

    service.applyDetectedPreviewURL(URL(string: "http://127.0.0.1:5173/")!)

    #expect(service.previewURL?.absoluteString == "http://127.0.0.1:5173/")
  }

  @Test
  func hiddenContextImmediatelyResolvesProjectMetadataForWorkingDirectory() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Pirate Check",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))
    let projectURL = URL(fileURLWithPath: project.workingDirectory, isDirectory: true)
    let screenshotURL = projectURL.appendingPathComponent("resources/screenshot.png")
    let referenceURL = projectURL.appendingPathComponent("resources/codebase-references/App.md")
    try FileManager.default.createDirectory(
      at: referenceURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("image".utf8).write(to: screenshotURL)
    try Data("# App reference".utf8).write(to: referenceURL)
    let service = ChatService(projectManager: projectManager)

    await service.startNewSession(workingDirectory: project.workingDirectory)

    let context = service.makeHiddenContextForCurrentState(nil)
    #expect(context.contains("Current project type: Prototype"))
    #expect(context.contains("Current prototype fidelity: High fidelity"))
    #expect(context.contains("Prototype fidelity contract"))
    #expect(context.contains(EaselProjectFidelity.highFidelity.agentGuidance.trimmingCharacters(in: .whitespacesAndNewlines)))
    #expect(context.contains("- `resources/screenshot.png`"))
    #expect(context.contains("- `resources/codebase-references/App.md`"))
  }

  @Test
  func resourceManifestDeltaContextReportsChangesAfterFullContextSnapshot() async throws {
    let rootDirectory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }

    let projectManager = LocalEaselProjectManager(rootDirectory: rootDirectory)
    let project = try await projectManager.createProject(from: EaselProjectCreateRequest(
      name: "Asset Delta",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity
    ))
    let projectURL = URL(fileURLWithPath: project.workingDirectory, isDirectory: true)
    let existingURL = projectURL.appendingPathComponent("resources/existing.png")
    let removedURL = projectURL.appendingPathComponent("resources/remove-me.png")
    let addedURL = projectURL.appendingPathComponent("resources/new.png")
    try Data("original image".utf8).write(to: existingURL)
    try Data("obsolete image".utf8).write(to: removedURL)
    let service = ChatService(projectManager: projectManager)

    await service.startNewSession(workingDirectory: project.workingDirectory)
    _ = service.makeHiddenContextForCurrentState(nil)

    try await Task.sleep(for: .milliseconds(20))
    try Data("updated image contents".utf8).write(to: existingURL)
    try Data("new image".utf8).write(to: addedURL)
    try FileManager.default.removeItem(at: removedURL)

    let context = service.makeResourceManifestDeltaContextForCurrentState()
    #expect(context?.contains("Added resources:") == true)
    #expect(context?.contains("- `resources/new.png`") == true)
    #expect(context?.contains("Updated resources:") == true)
    #expect(context?.contains("- `resources/existing.png`") == true)
    #expect(context?.contains("Removed resources:") == true)
    #expect(context?.contains("- `resources/remove-me.png`") == true)
    #expect(service.makeResourceManifestDeltaContextForCurrentState() == nil)
  }

  @Test
  func clearingActiveWorkspaceDropsProjectAndPreviewState() {
    let service = ChatService()
    let project = EaselDesignProject(
      id: UUID(),
      name: "Archive",
      kind: .prototype,
      designSystem: .none,
      fidelity: .highFidelity,
      workingDirectory: "/tmp/archive",
      createdAt: Date(),
      updatedAt: Date()
    )

    service.setCurrentProject(project)
    service.setPreviewURL(URL(string: "http://localhost:4301/")!)

    service.clearActiveWorkspace()

    #expect(service.currentWorkingDirectory == nil)
    #expect(service.currentProject == nil)
    #expect(service.currentSessionId == nil)
    #expect(service.previewURL == nil)
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("ChatServiceTests-\(UUID().uuidString)", isDirectory: true)
  }
}
