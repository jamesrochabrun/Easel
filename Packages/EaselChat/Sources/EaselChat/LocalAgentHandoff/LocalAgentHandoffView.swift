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

  @State private var isFolderImporterPresented = false
  @State private var folderImportMode: FolderImportMode = .repository
  @Environment(\.colorScheme) private var colorScheme

  private enum FolderImportMode {
    case repository
    case projectRoot
  }

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
        VStack(alignment: .leading, spacing: 26) {
          LocalAgentHandoffSection(title: "Agent") {
            LocalAgentHandoffProviderPicker(viewModel: viewModel)
          }

          LocalAgentHandoffSection(title: "Destination") {
            LocalAgentHandoffTargetPicker(
              viewModel: viewModel,
              context: context,
              onSelectRepository: showRepositoryImporter,
              onCreateProject: createProjectFolder
            )
          }

          LocalAgentHandoffDetailsSection(viewModel: viewModel)

          LocalAgentHandoffResourcesSection(context: context)

          LocalAgentHandoffStatusView(
            errorMessage: viewModel.errorMessage,
            successMessage: viewModel.successMessage
          )
        }
        .frame(maxWidth: 560, alignment: .leading)
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
      isPresented: $isFolderImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        guard let url = urls.first else { return }
        switch folderImportMode {
        case .repository:
          viewModel.selectRepository(url)
        case .projectRoot:
          createProjectFolder(in: url)
        }
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
    folderImportMode = .repository
    isFolderImporterPresented = true
  }

  private func createProjectFolder() {
    folderImportMode = .projectRoot
    isFolderImporterPresented = true
  }

  private func createProjectFolder(in parentDirectory: URL) {
    guard let context else { return }
    Task {
      await viewModel.createProject(context: context, in: parentDirectory)
    }
  }
}
