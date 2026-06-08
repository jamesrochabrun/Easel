//
//  DesignSystemSetupViewModelTests.swift
//  EaselChatTests
//

import Foundation
import Testing
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
}
