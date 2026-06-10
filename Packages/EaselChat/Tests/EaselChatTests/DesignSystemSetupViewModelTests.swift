//
//  DesignSystemSetupViewModelTests.swift
//  EaselChatTests
//

import Foundation
import Testing
import EaselDesignSystems
@testable import EaselChat

@MainActor
struct DesignSystemSetupViewModelTests {

  @Test
  func addFigFilesAcceptsOnlyFigFiles() {
    let viewModel = DesignSystemSetupViewModel()

    viewModel.addFigFiles([
      URL(fileURLWithPath: "/tmp/Brand.fig"),
      URL(fileURLWithPath: "/tmp/notes.txt"),
      URL(fileURLWithPath: "/tmp/logo.png"),
      URL(fileURLWithPath: "/tmp/System.FIG"),
    ])

    #expect(viewModel.figFileURLs.map(\.lastPathComponent) == ["Brand.fig", "System.FIG"])
  }

  @Test
  func addFigFilesIgnoresDuplicates() {
    let viewModel = DesignSystemSetupViewModel()

    viewModel.addFigFiles([URL(fileURLWithPath: "/tmp/Brand.fig")])
    viewModel.addFigFiles([URL(fileURLWithPath: "/tmp/Brand.fig")])

    #expect(viewModel.figFileURLs.count == 1)
  }

  @Test
  func createDesignSystemExtractsFigFilesByDefault() async throws {
    let manager = RecordingDesignSystemSetupManager()
    let viewModel = DesignSystemSetupViewModel(designSystemManager: manager)
    viewModel.blurb = "Brand System"
    viewModel.addFigFiles([URL(fileURLWithPath: "/tmp/System.fig")])

    _ = await viewModel.createDesignSystem()

    let requests = await manager.createRequests()
    let request = try #require(requests.first)
    #expect(request.figImportMode == .extractCatalog)
  }
}

private actor RecordingDesignSystemSetupManager: EaselDesignSystemManaging {
  private var requests: [EaselDesignSystemCreateRequest] = []

  func loadDesignSystems() async throws -> [EaselDesignSystemProfile] {
    []
  }

  func createDesignSystem(from request: EaselDesignSystemCreateRequest) async throws -> EaselDesignSystemProfile {
    requests.append(request)
    return EaselDesignSystemProfile(
      id: UUID(),
      name: "Brand System",
      blurb: request.blurb,
      notes: request.notes,
      sourceLinks: request.sourceLinks,
      workingDirectory: "/tmp/brand-system",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  func deleteDesignSystem(_ profile: EaselDesignSystemProfile) async throws {}

  func loadCatalog(forDesignSystemAt path: String) async throws -> EaselDesignSystemCatalog? {
    nil
  }

  func createRequests() -> [EaselDesignSystemCreateRequest] {
    requests
  }
}
