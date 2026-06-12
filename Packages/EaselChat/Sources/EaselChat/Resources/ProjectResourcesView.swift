//
//  ProjectResourcesView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI
import UniformTypeIdentifiers

public struct ProjectResourcesView: View {
  @Bindable var viewModel: ProjectResourcesViewModel
  let currentProjectPath: String?

  @State private var isImporterPresented = false
  @State private var isDropTargeted = false
  @State private var itemPendingDeletion: ProjectResourcePanelItem?

  public init(
    viewModel: ProjectResourcesViewModel,
    currentProjectPath: String?
  ) {
    self.viewModel = viewModel
    self.currentProjectPath = currentProjectPath
  }

  /// Files can be dropped to add resources whenever a project is active and an
  /// import isn't already in flight — mirroring the "Add Design Files" button.
  private var canImportDroppedFiles: Bool {
    viewModel.selectedProjectPath != nil && !viewModel.isImporting
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
    .onDrop(of: [.item], isTargeted: $isDropTargeted) { providers in
      guard canImportDroppedFiles, !providers.isEmpty else { return false }
      Task {
        await importDroppedProviders(providers)
      }
      return true
    }
    .overlay {
      if isDropTargeted && canImportDroppedFiles {
        dropTargetOverlay
      }
    }
    .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
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
    .confirmationDialog(
      itemPendingDeletion.map { "Delete \($0.fileName)?" } ?? "Delete file?",
      isPresented: deletionConfirmationBinding,
      titleVisibility: .visible,
      presenting: itemPendingDeletion
    ) { item in
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteItem(item) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { item in
      Text("\"\(item.fileName)\" will be removed from this project. This can't be undone.")
    }
  }

  /// Resolves dropped items to on-disk files and imports them. Finder files come
  /// through as file URLs; screenshots and other app-vended assets arrive as data
  /// (e.g. PNG), so those are written to a temporary file first. This way every
  /// asset type imports, matching the "Add Design Files" button.
  private func importDroppedProviders(_ providers: [NSItemProvider]) async {
    var fileURLs: [URL] = []
    for provider in providers {
      if let url = await Self.loadDroppedFile(from: provider) {
        fileURLs.append(url)
      }
    }

    guard !fileURLs.isEmpty else { return }
    await viewModel.importResources(from: fileURLs)
  }

  /// Loads a provider's contents into a temporary file we own, copying it out of
  /// the system-supplied location before that location is invalidated.
  private static func loadDroppedFile(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, _ in
        guard let url else {
          continuation.resume(returning: nil)
          return
        }

        let destinationDirectory = FileManager.default.temporaryDirectory
          .appendingPathComponent("EaselDroppedAssets/\(UUID().uuidString)", isDirectory: true)
        let destination = destinationDirectory.appendingPathComponent(url.lastPathComponent)

        do {
          try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: url, to: destination)
          continuation.resume(returning: destination)
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private var deletionConfirmationBinding: Binding<Bool> {
    Binding(
      get: { itemPendingDeletion != nil },
      set: { if !$0 { itemPendingDeletion = nil } }
    )
  }

  private func requestDelete(_ item: ProjectResourcePanelItem) {
    itemPendingDeletion = item
  }

  private var dropTargetOverlay: some View {
    ZStack {
      Rectangle()
        .fill(.regularMaterial)

      VStack(spacing: 10) {
        Image(systemName: "tray.and.arrow.down")
          .font(.system(size: 30, weight: .light))
        Text("Drop files to add to this project")
          .font(.callout.weight(.medium))
      }
      .foregroundStyle(.primary)
    }
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        .padding(8)
    }
    .allowsHitTesting(false)
    .transition(.opacity)
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
        onBack: viewModel.clearSelection,
        onDelete: requestDelete
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
