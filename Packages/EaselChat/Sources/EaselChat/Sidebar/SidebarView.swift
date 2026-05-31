//
//  SidebarView.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselKit
import SwiftUI

public struct SidebarView: View {
  @Bindable var sidebarViewModel: SidebarViewModel

  @State private var showDeleteConfirmation = false
  @State private var sessionToDelete: StoredSession?
  @Environment(\.colorScheme) private var colorScheme

  public init(sidebarViewModel: SidebarViewModel) {
    self.sidebarViewModel = sidebarViewModel
  }

  public var body: some View {
    VStack(spacing: 0) {
      headerView

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          newProjectCard
          projectList
        }
        .padding(12)
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
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
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "sparkles")
          .font(EaselDesignSystem.Typography.interface(size: 15, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.accent)

        Text("Easel")
          .font(EaselDesignSystem.Typography.interface(size: 22, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Text("Codex")
          .font(EaselDesignSystem.Typography.interface(size: 11, weight: .medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: Capsule())
          .overlay {
            Capsule()
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
      }

      Text("Prototype workspace")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineLimit(1)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var newProjectCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Project type", selection: $sidebarViewModel.selectedProjectKind) {
        ForEach(EaselProjectKind.allCases) { kind in
          Text(kind.displayName).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      Text(sidebarViewModel.selectedProjectKind.creationTitle)
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)

      TextField(
        sidebarViewModel.selectedProjectKind.placeholderName,
        text: $sidebarViewModel.projectName
      )
      .textFieldStyle(.plain)
      .font(EaselDesignSystem.Typography.interface(size: 14))
      .padding(.horizontal, 12)
      .frame(height: 42)
      .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Design system")
          .font(.callout.weight(.medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        Picker("Design system", selection: $sidebarViewModel.selectedDesignSystem) {
          ForEach(EaselDesignSystemPreset.allCases) { system in
            Text(system.displayName).tag(system)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      fidelityPicker

      if let creationError = sidebarViewModel.creationError {
        Text(creationError)
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button {
        Task {
          await sidebarViewModel.createProjectAndStartSession()
        }
      } label: {
        Label(
          sidebarViewModel.isCreatingProject ? "Creating" : "Create",
          systemImage: sidebarViewModel.isCreatingProject ? "hourglass" : "plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(EaselDesignSystem.Palette.primaryAction(for: colorScheme))
      .controlSize(.large)
      .disabled(!canCreateProject || sidebarViewModel.isCreatingProject)
    }
    .padding(12)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private var fidelityPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Fidelity")
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      HStack(spacing: 10) {
        ForEach(EaselProjectFidelity.allCases) { fidelity in
          Button {
            sidebarViewModel.selectedFidelity = fidelity
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              fidelityThumbnail(for: fidelity)
                .frame(height: 72)

              Text(fidelity.displayName)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
            .overlay {
              RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
                .stroke(
                  sidebarViewModel.selectedFidelity == fidelity ? EaselDesignSystem.Palette.accent : Color.clear,
                  lineWidth: 2
                )
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(fidelity.displayName)
        }
      }
    }
  }

  private func fidelityThumbnail(for fidelity: EaselProjectFidelity) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7)
        .fill(EaselDesignSystem.Palette.surfaceElevated(for: colorScheme))

      RoundedRectangle(cornerRadius: 6)
        .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
        .padding(8)

      if fidelity == .wireframe {
        wireframeThumbnail
          .padding(16)
      } else {
        highFidelityThumbnail
          .padding(16)
      }
    }
  }

  private var wireframeThumbnail: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 3)
          .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        RoundedRectangle(cornerRadius: 3)
          .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
      }
      RoundedRectangle(cornerRadius: 3)
        .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
    }
  }

  private var highFidelityThumbnail: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Circle()
          .fill(EaselDesignSystem.Palette.accent)
          .frame(width: 8, height: 8)

        RoundedRectangle(cornerRadius: 3)
          .fill(Color.secondary.opacity(0.35))
          .frame(width: 38, height: 6)

        Spacer()

        RoundedRectangle(cornerRadius: 4)
          .fill(EaselDesignSystem.Palette.accent)
          .frame(width: 32, height: 10)
      }

      RoundedRectangle(cornerRadius: 3)
        .fill(Color.primary.opacity(0.62))
        .frame(width: 70, height: 10)

      RoundedRectangle(cornerRadius: 3)
        .fill(Color.secondary.opacity(0.38))
        .frame(height: 7)

      HStack {
        RoundedRectangle(cornerRadius: 6)
          .fill(EaselDesignSystem.Palette.accent)
          .frame(width: 46, height: 15)

        Spacer()

        Image(systemName: "photo")
          .foregroundStyle(EaselDesignSystem.Palette.accent.opacity(0.65))
      }
    }
  }

  private var projectList: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Projects")
          .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))
          .foregroundStyle(.primary)

        Spacer()

        Button {
          Task {
            await sidebarViewModel.loadSessions()
          }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Refresh projects")
      }

      if sidebarViewModel.projectGroups.isEmpty {
        Text("No projects yet")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 8)
      } else {
        LazyVStack(alignment: .leading, spacing: 6) {
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
              if project.sessions.isEmpty {
                Text("No sessions yet")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
                  .padding(.horizontal, 12)
                  .padding(.bottom, 6)
              } else {
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
                  .padding(.leading, 6)
                }
              }
            }
          }
        }
      }
    }
  }

  private var canCreateProject: Bool {
    !sidebarViewModel.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
