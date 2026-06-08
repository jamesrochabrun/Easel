//
//  ProjectResourcesView.swift
//  EaselChat
//

import EaselDesignSystems
import SwiftUI
import UniformTypeIdentifiers

public struct ProjectResourcesView: View {
  @Bindable var viewModel: ProjectResourcesViewModel
  let currentProjectPath: String?

  @State private var isImporterPresented = false

  public init(
    viewModel: ProjectResourcesViewModel,
    currentProjectPath: String?
  ) {
    self.viewModel = viewModel
    self.currentProjectPath = currentProjectPath
  }

  public var body: some View {
    VStack(spacing: 0) {
      controls

      if let errorMessage = viewModel.errorMessage {
        ProjectResourceErrorBanner(message: errorMessage)
      }

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      content
    }
    .background(.background)
    .task(id: currentProjectPath ?? "") {
      await viewModel.refresh(currentProjectPath: currentProjectPath)
    }
    .task(id: resourcesObservationID) {
      await observeResourceDirectoryChanges()
    }
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: [.item],
      allowsMultipleSelection: true
    ) { result in
      Task {
        switch result {
        case let .success(urls):
          await viewModel.importResources(from: urls)
        case let .failure(error):
          viewModel.reportImportFailure(error)
        }
      }
    }
  }

  private var resourcesObservationID: String {
    viewModel.selectedProjectPath ?? currentProjectPath ?? ""
  }

  private var controls: some View {
    HStack(spacing: 10) {
      if let selectedProject = viewModel.selectedProject {
        Label(selectedProject.kind.displayName, systemImage: selectedProject.kind.systemImage)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.thinMaterial, in: Capsule())
      } else if let selectedDesignSystem = viewModel.selectedDesignSystem {
        Label(selectedDesignSystem.name, systemImage: "paintpalette")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.thinMaterial, in: Capsule())
      } else {
        Text("No active workspace")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        Task {
          await viewModel.refresh()
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Refresh design files")
      .disabled(viewModel.isLoading || viewModel.isImporting)

      Button {
        isImporterPresented = true
      } label: {
        Label(
          viewModel.isImporting ? "Adding" : "Add Design Files",
          systemImage: viewModel.isImporting ? "hourglass" : "plus"
        )
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .disabled(viewModel.selectedProjectPath == nil || viewModel.isImporting)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(minHeight: 52)
  }

  @ViewBuilder
  private var content: some View {
    if viewModel.isLoading {
      ProgressView("Loading design files...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if viewModel.selectedProjectPath == nil {
      ProjectResourcesEmptyState(
        systemImage: "folder.badge.plus",
        title: "No active workspace",
        message: "Open a project or design system to see its files."
      )
    } else if !viewModel.hasProjectFiles {
      ProjectResourcesEmptyState(
        systemImage: "doc.badge.plus",
        title: "No design files",
        message: "This project does not contain imported resources or generated files yet."
      )
    } else {
      ProjectResourcesContentView(
        resources: viewModel.resources,
        projectStructureSections: viewModel.projectStructureSections,
        selectedItem: viewModel.selectedItem,
        selectedPreview: viewModel.selectedPreview,
        isPreviewLoading: viewModel.isPreviewLoading,
        isSavingPreview: viewModel.isSavingPreview,
        onSelect: selectItem,
        onSaveText: saveText,
        onBack: viewModel.clearSelection
      )
    }
  }

  private func selectItem(_ item: ProjectResourcePanelItem) {
    Task {
      await viewModel.select(item)
    }
  }

  private func saveText(_ item: ProjectResourcePanelItem, _ text: String) {
    Task {
      await viewModel.saveTextPreview(text, for: item)
    }
  }

  private func observeResourceDirectoryChanges() async {
    guard let projectPath = viewModel.selectedProjectPath ?? currentProjectPath,
          !projectPath.isEmpty else {
      return
    }

    let observer = ProjectResourceDirectoryChangeObserver(projectPath: projectPath)
    _ = await observer.hasChangedSinceLastSnapshot()

    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(800))
      guard !Task.isCancelled else { return }

      if await observer.hasChangedSinceLastSnapshot() {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }

        _ = await observer.hasChangedSinceLastSnapshot()
        await viewModel.refresh(currentProjectPath: projectPath)
      }
    }
  }
}
