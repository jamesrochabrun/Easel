//
//  LocalAgentHandoffView.swift
//  EaselChat
//

import EaselKit
import SwiftUI
import UniformTypeIdentifiers

public struct LocalAgentHandoffView: View {
  @Bindable var viewModel: LocalAgentHandoffViewModel
  let context: LocalAgentHandoffContext?
  let onClose: () -> Void

  @State private var isRepositoryImporterPresented = false
  @State private var isProjectRootImporterPresented = false
  @Environment(\.colorScheme) private var colorScheme

  public init(
    viewModel: LocalAgentHandoffViewModel,
    context: LocalAgentHandoffContext?,
    onClose: @escaping () -> Void
  ) {
    self.viewModel = viewModel
    self.context = context
    self.onClose = onClose
  }

  public var body: some View {
    VStack(spacing: 0) {
      LocalAgentHandoffHeader(onClose: onClose)

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack(alignment: .top, spacing: 22) {
            LocalAgentHandoffSection(title: "Agent") {
              LocalAgentHandoffProviderPicker(viewModel: viewModel)
            }
            .frame(width: 220)

            LocalAgentHandoffSection(title: "Target") {
              LocalAgentHandoffTargetPicker(
                viewModel: viewModel,
                context: context,
                onSelectRepository: showRepositoryImporter,
                onCreateProject: createProjectFolder
              )
            }
            .layoutPriority(1)
          }

          LocalAgentHandoffDetailsSection(viewModel: viewModel)
          LocalAgentHandoffResourcesSection(context: context)

          LocalAgentHandoffStatusView(
            errorMessage: viewModel.errorMessage,
            successMessage: viewModel.successMessage
          )
        }
        .frame(maxWidth: 680)
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
      }

      LocalAgentHandoffFooter(
        isLaunching: viewModel.isLaunching,
        canLaunch: viewModel.canLaunch(context: context),
        onCancel: onClose,
        onStart: startAgent
      )
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isRepositoryImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        guard let url = urls.first else { return }
        viewModel.selectRepository(url)
      case let .failure(error):
        viewModel.reportRepositorySelectionFailure(error)
      }
    }
    .fileImporter(
      isPresented: $isProjectRootImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        guard let url = urls.first else { return }
        createProjectFolder(in: url)
      case let .failure(error):
        viewModel.reportRepositorySelectionFailure(error)
      }
    }
    .onChange(of: viewModel.selectedTarget) { _, target in
      if target == .selectedRepository && viewModel.selectedRepositoryPath == nil {
        showRepositoryImporter()
      }
    }
  }

  private func startAgent() {
    guard let context else { return }
    Task {
      await viewModel.launch(context: context)
    }
  }

  private func showRepositoryImporter() {
    isRepositoryImporterPresented = true
  }

  private func createProjectFolder() {
    isProjectRootImporterPresented = true
  }

  private func createProjectFolder(in parentDirectory: URL) {
    guard let context else { return }
    Task {
      await viewModel.createProject(context: context, in: parentDirectory)
    }
  }
}
