//
//  BackgroundAgentJobModelsTests.swift
//  EaselKitTests
//

import Foundation
import Testing
@testable import EaselKit

struct BackgroundAgentJobModelsTests {

  @Test
  func activeStatuses() {
    #expect(BackgroundAgentJobStatus.queued.isActive)
    #expect(BackgroundAgentJobStatus.preparingWorkspace.isActive)
    #expect(BackgroundAgentJobStatus.generating.isActive)
    #expect(BackgroundAgentJobStatus.validating.isActive)
    #expect(BackgroundAgentJobStatus.waitingToApply.isActive)
    #expect(BackgroundAgentJobStatus.applying.isActive)
  }

  @Test
  func terminalStatuses() {
    #expect(!BackgroundAgentJobStatus.applied(undoAvailable: true).isActive)
    #expect(!BackgroundAgentJobStatus.conflict(driftedFiles: ["index.html"]).isActive)
    #expect(!BackgroundAgentJobStatus.failed(.timedOut).isActive)
    #expect(!BackgroundAgentJobStatus.cancelled.isActive)
    #expect(!BackgroundAgentJobStatus.undone.isActive)
  }

  @Test
  func statusEqualityDistinguishesAssociatedValues() {
    #expect(
      BackgroundAgentJobStatus.conflict(driftedFiles: ["a"])
        != .conflict(driftedFiles: ["b"])
    )
    #expect(
      BackgroundAgentJobStatus.failed(.agentFailed("x"))
        != .failed(.agentFailed("y"))
    )
    #expect(
      BackgroundAgentJobStatus.applied(undoAvailable: true)
        != .applied(undoAvailable: false)
    )
  }

  @Test
  func failureMessagesAreUserFacing() {
    #expect(BackgroundAgentJobFailure.timedOut.message == "Generation timed out")
    #expect(BackgroundAgentJobFailure.agentFailed("codex exited 1").message == "codex exited 1")
    #expect(
      BackgroundAgentJobFailure.validationFailed("No dc_set_props schema found").message
        == "No dc_set_props schema found"
    )
    #expect(
      BackgroundAgentJobFailure.workspacePreparationFailed("disk full").message.contains("disk full")
    )
    #expect(BackgroundAgentJobFailure.applyFailed("locked").message.contains("locked"))
  }

  @Test
  func ignoreListCoversObserverCriticalDirectories() {
    for name in [".git", ".easel", "node_modules", "dist", "out", ".build"] {
      #expect(ProjectScanIgnoreList.directoryNames.contains(name))
    }
  }
}
