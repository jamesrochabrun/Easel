//
//  SidebarView.swift
//  EaselChat
//

import AppKit
import ClaudeCodeCore
import SwiftUI

public struct SidebarView: View {
  @Bindable var sidebarViewModel: SidebarViewModel

  @State private var showDeleteConfirmation = false
  @State private var sessionToDelete: StoredSession?

  public init(sidebarViewModel: SidebarViewModel) {
    self.sidebarViewModel = sidebarViewModel
  }

  public var body: some View {
    VStack(spacing: 0) {
      headerView

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(sidebarViewModel.projectGroups) { project in
            ProjectHeaderView(
              project: project,
              onToggle: {
                sidebarViewModel.toggleProject(project.id)
              },
              onNewChat: {
                sidebarViewModel.requestNewChat(workingDirectory: project.workingDirectory)
              }
            )

            if project.isExpanded {
              ForEach(project.sessions) { session in
                SidebarSessionRow(
                  session: session,
                  isSelected: session.id == sidebarViewModel.selectedSessionId,
                  onSelect: {
                    sidebarViewModel.selectSession(session)
                  },
                  onDelete: {
                    sessionToDelete = session
                    showDeleteConfirmation = true
                  }
                )
                .padding(.leading, 8)
              }
            }
          }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 4)
      }
    }
    .alert("Delete Session", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        sessionToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let session = sessionToDelete {
          sidebarViewModel.deleteSession(session)
          sessionToDelete = nil
        }
      }
    } message: {
      Text("Are you sure you want to delete this session? This action cannot be undone.")
    }
    .task {
      await sidebarViewModel.loadSessions()
    }
  }

  private var headerView: some View {
    HStack {
      Text("Projects")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.primary)

      Spacer()

      Button {
        addExistingProject()
      } label: {
        Image(systemName: "folder")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
      .help("Add existing project")

      Button {
        createNewProject()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
      .help("Create new project")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minHeight: 40)
  }

  private func addExistingProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Select a project folder"
    panel.prompt = "Open"

    if panel.runModal() == .OK, let url = panel.url {
      sidebarViewModel.requestNewChat(workingDirectory: url.path)
    }
  }

  private func createNewProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.message = "Choose location and create a new project folder"
    panel.prompt = "Create"

    if panel.runModal() == .OK, let url = panel.url {
      sidebarViewModel.requestNewChat(workingDirectory: url.path)
    }
  }
}
