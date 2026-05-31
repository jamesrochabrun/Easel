//
//  ProjectResourcesView.swift
//  EaselChat
//

import SwiftUI
import UniformTypeIdentifiers

public struct ProjectResourcesView: View {
  @Environment(\.openURL) private var openURL

  @Bindable var viewModel: ProjectResourcesViewModel
  let currentProjectPath: String?

  @State private var isImporterPresented = false

  private let columns = [
    GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 12)
  ]

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

  private var controls: some View {
    HStack(spacing: 10) {
      if viewModel.projects.isEmpty {
        Text("No projects")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        Picker("Project", selection: $viewModel.selectedProjectPath) {
          ForEach(viewModel.projects) { project in
            Text(project.name)
              .tag(Optional(project.workingDirectory))
          }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 220, maxWidth: 320, alignment: .leading)
        .onChange(of: viewModel.selectedProjectPath) {
          Task {
            await viewModel.loadResourcesForSelection()
          }
        }
      }

      if let selectedProject = viewModel.selectedProject {
        Label(selectedProject.kind.displayName, systemImage: selectedProject.kind.systemImage)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.thinMaterial, in: Capsule())
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
      .help("Refresh resources")
      .disabled(viewModel.isLoading || viewModel.isImporting)

      Button {
        isImporterPresented = true
      } label: {
        Label(
          viewModel.isImporting ? "Adding" : "Add Resources",
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
      ProgressView("Loading resources...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if viewModel.projects.isEmpty {
      ProjectResourcesEmptyState(
        systemImage: "folder.badge.plus",
        title: "No projects yet",
        message: "Create or open a project before adding resources."
      )
    } else if viewModel.resources.isEmpty {
      ProjectResourcesEmptyState(
        systemImage: "photo.on.rectangle.angled",
        title: "No resources",
        message: "Add images, documents, PDFs, and other project assets here."
      )
    } else {
      ScrollView {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
          ForEach(viewModel.resources) { resource in
            ProjectResourceCard(resource: resource) {
              openURL(resource.fileURL)
            }
          }
        }
        .padding(16)
      }
    }
  }
}
