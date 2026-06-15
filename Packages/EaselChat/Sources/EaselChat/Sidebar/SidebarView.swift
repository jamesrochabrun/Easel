//
//  SidebarView.swift
//  EaselChat
//

import ClaudeCodeCore
import EaselDesignSystems
import EaselKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct SidebarView: View {
  @Bindable var sidebarViewModel: SidebarViewModel
  private let reservesWindowControls: Bool

  @State private var showDeleteSessionConfirmation = false
  @State private var showDeleteProjectConfirmation = false
  @State private var showDeleteDesignSystemConfirmation = false
  @State private var sessionToDelete: StoredSession?
  @State private var projectToDelete: ProjectGroup?
  @State private var designSystemToDelete: EaselDesignSystemProfile?
  @State private var designSystemDeleteConfirmationName = ""
  @State private var isCodebaseImporterPresented = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let projectKindChangeAnimation = Animation.easeInOut(duration: 0.22)

  public init(sidebarViewModel: SidebarViewModel, reservesWindowControls: Bool = false) {
    self.sidebarViewModel = sidebarViewModel
    self.reservesWindowControls = reservesWindowControls
  }

  public var body: some View {
    VStack(spacing: 0) {
      headerView

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      ScrollViewReader { scrollProxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            newProjectCard
            projectList
          }
          .padding(12)
        }
        .onAppear {
          fulfillProjectHeaderScrollRequest(with: scrollProxy)
        }
        .onChange(of: sidebarViewModel.projectHeaderScrollRequest) { _, _ in
          fulfillProjectHeaderScrollRequest(with: scrollProxy)
        }
        .onChange(of: projectGroupIDs) { _, _ in
          fulfillProjectHeaderScrollRequest(with: scrollProxy)
        }
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
    .alert("Delete Session", isPresented: $showDeleteSessionConfirmation) {
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
    .alert("Delete Project", isPresented: $showDeleteProjectConfirmation) {
      Button("Cancel", role: .cancel) {
        projectToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let project = projectToDelete {
          Task {
            await sidebarViewModel.deleteProject(project)
            projectToDelete = nil
          }
        }
      }
    } message: {
      Text(projectDeleteConfirmationMessage)
    }
    .alert("Delete Design System", isPresented: $showDeleteDesignSystemConfirmation) {
      TextField("Design system name", text: $designSystemDeleteConfirmationName)
      Button("Cancel", role: .cancel) {
        resetDesignSystemDeleteConfirmation()
      }
      Button("Delete", role: .destructive) {
        if let designSystem = designSystemToDelete {
          Task {
            await sidebarViewModel.deleteDesignSystem(designSystem)
            resetDesignSystemDeleteConfirmation()
          }
        }
      }
      .disabled(!canConfirmDesignSystemDeletion)
    } message: {
      Text(designSystemDeleteConfirmationMessage)
    }
    .sheet(item: $sidebarViewModel.highFidelityContextRequest) { _ in
      HighFidelityProjectContextPickerView(
        selectedDesignSystemName: selectedContextDesignSystemName,
        onDesignSystem: handleDesignSystemContextSelection,
        onStart: createProject
      )
      .frame(width: 560, height: 620)
    }
    .sheet(item: $sidebarViewModel.wireframeContextRequest) { _ in
      WireframeProjectContextPickerView(onStart: createProject)
        .frame(width: 560, height: 420)
    }
    .sheet(item: $sidebarViewModel.slideDeckContextRequest) { _ in
      SlideDeckProjectContextPickerView(onStart: createProject)
        .frame(width: 640, height: 580)
    }
    .task {
      await sidebarViewModel.loadSessions()
    }
    .fileImporter(
      isPresented: $isCodebaseImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        guard let url = urls.first else { return }
        sidebarViewModel.selectCodebase(url)
      case let .failure(error):
        sidebarViewModel.reportCodebaseSelectionFailure(error)
      }
    }
  }

  private var headerView: some View {
    HStack(alignment: .center, spacing: 5) {
      Image("easelmenubar")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundStyle(headerIconForegroundColor)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)

      Text("Easel")
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .padding(.leading, headerLeadingPadding)
    .padding(.trailing, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
  }

  private var headerIconForegroundColor: Color {
    colorScheme == .dark ? .white : EaselDesignSystem.Palette.accent
  }

  private var headerLeadingPadding: CGFloat {
    reservesWindowControls ? 78 : 16
  }

  private var newProjectCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Project type", selection: projectKindSelection) {
        ForEach(EaselProjectKind.allCases) { kind in
          Text(kind.displayName).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .transaction { transaction in
        transaction.animation = nil
      }

      Text(sidebarViewModel.selectedProjectKind.creationTitle)
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)

      TextField(
        sidebarViewModel.selectedProjectKind.placeholderName,
        text: $sidebarViewModel.projectName
      )
      .textFieldStyle(.plain)
      .font(EaselDesignSystem.Typography.interface(size: 14))
      .tint(EaselDesignSystem.Palette.selectionAccent(for: colorScheme))
      .padding(.horizontal, 12)
      .frame(height: 42)
      .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Design system")
            .font(.callout.weight(.medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

          Spacer()

          Button {
            sidebarViewModel.requestBrowseDesignSystems()
          } label: {
            Image(systemName: "rectangle.grid.1x2")
              .font(.system(size: 13, weight: .medium))
          }
          .buttonStyle(.plain)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .help("Browse design systems")
        }

        if sidebarViewModel.shouldShowCreateOnlyDesignSystemControl {
          createDesignSystemButton
        } else {
          HStack(spacing: 6) {
            Menu {
              ForEach(sidebarViewModel.availableDesignSystemChoices) { system in
                Button {
                  sidebarViewModel.selectDesignSystem(system)
                } label: {
                  if sidebarViewModel.selectedDesignSystem == system {
                    Label(system.displayName, systemImage: "checkmark")
                  } else {
                    Text(system.displayName)
                  }
                }
              }

              Divider()

              Button("Create Design System", systemImage: "plus", action: sidebarViewModel.requestCreateDesignSystem)
            } label: {
              HStack(spacing: 8) {
                Text(sidebarViewModel.selectedDesignSystem.displayName)
                  .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              }
              .font(EaselDesignSystem.Typography.interface(size: 14, weight: .medium))
              .foregroundStyle(.primary)
              .padding(.horizontal, 12)
              .frame(height: 34)
              .frame(maxWidth: .infinity)
              .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
              .overlay {
                RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
                  .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
              }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let selectedCustomDesignSystem = sidebarViewModel.selectedCustomDesignSystem {
              ProjectHeaderActionButton(
                title: "Delete design system",
                systemImage: "trash",
                role: .destructive,
                foregroundColor: EaselDesignSystem.Palette.secondaryText(for: colorScheme),
                hoverColor: EaselDesignSystem.Palette.hoverSurface(for: colorScheme),
                action: {
                  requestDeleteDesignSystem(selectedCustomDesignSystem)
                }
              )
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let designSystemError = sidebarViewModel.designSystemError {
          Text(designSystemError)
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.danger)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if sidebarViewModel.shouldShowFidelityPicker {
        fidelityPicker
          .transition(projectKindContentTransition)
      }

      if sidebarViewModel.shouldShowCodebasePicker {
        HighFidelityCodebasePicker(
          codebasePath: sidebarViewModel.selectedCodebasePath,
          onSelect: showCodebaseImporter,
          onClear: sidebarViewModel.clearCodebasePath
        )
        .transition(projectKindContentTransition)
      }

      if let creationError = sidebarViewModel.creationError {
        Text(creationError)
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button {
        handleCreateProjectButton()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: sidebarViewModel.isCreatingProject ? "hourglass" : "plus")
            .font(.callout.weight(.medium))

          Text(sidebarViewModel.isCreatingProject ? "Creating" : "Create")
            .font(.callout.weight(.medium))

          Spacer()

          Text("⌘↩")
            .font(.caption.weight(.semibold))
            .foregroundStyle(createButtonShortcutForeground)
        }
        .foregroundStyle(createButtonForeground)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(
          createButtonBackground,
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        )
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(createButtonBorder, lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.return, modifiers: .command)
      .disabled(!canCreateProject || sidebarViewModel.isCreatingProject)
    }
    .padding(12)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private var projectKindSelection: Binding<EaselProjectKind> {
    Binding {
      sidebarViewModel.selectedProjectKind
    } set: { newKind in
      withAnimation(projectKindChangeAnimation) {
        sidebarViewModel.selectedProjectKind = newKind
      }
    }
  }

  private var projectKindContentTransition: AnyTransition {
    .opacity
  }

  private var createDesignSystemButton: some View {
    Button(action: sidebarViewModel.requestCreateDesignSystem) {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.callout.weight(.medium))

        Text("Create Design System")
          .font(.callout.weight(.medium))
          .lineLimit(1)

        Spacer()
      }
      .foregroundStyle(EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme))
      .padding(.horizontal, 12)
      .frame(height: 34)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        EaselDesignSystem.Palette.primaryAction(for: colorScheme),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .contentShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
    }
    .buttonStyle(.plain)
    .disabled(false)
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

              Text(fidelity.pickerDescription)
                .font(.caption)
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              fidelityTileBackground(isSelected: sidebarViewModel.selectedFidelity == fidelity),
              in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            )
            .overlay {
              RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
                .stroke(
                  sidebarViewModel.selectedFidelity == fidelity
                    ? EaselDesignSystem.Palette.selectionAccent(for: colorScheme)
                    : Color.clear,
                  lineWidth: 2
                )
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(fidelity.displayName)
          .accessibilityHint(fidelity.pickerDescription)
          .help("\(fidelity.displayName): \(fidelity.pickerDescription)")
        }
      }
    }
  }

  private func fidelityTileBackground(isSelected: Bool) -> Color {
    guard isSelected else {
      return EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
    }

    return colorScheme == .dark
      ? EaselDesignSystem.Palette.selectionAccent(for: colorScheme).opacity(0.12)
      : EaselDesignSystem.Palette.selectedSurface(for: colorScheme)
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
        Text("Designs")
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
        .help("Refresh designs")
      }

      if !sidebarViewModel.projectGroups.isEmpty || sidebarViewModel.isFilteringProjects {
        projectSearchField
      }

      if sidebarViewModel.projectGroups.isEmpty {
        Text("No projects or design systems yet")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 8)
      } else if sidebarViewModel.filteredProjectGroups.isEmpty {
        Text(projectSearchEmptyMessage)
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 8)
      } else {
        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(sidebarViewModel.filteredProjectGroups) { project in
            VStack(alignment: .leading, spacing: 6) {
              ProjectHeaderView(
                project: project,
                onToggle: {
                  sidebarViewModel.openWorkspace(project)
                  withAnimation(projectListAnimation) {
                    sidebarViewModel.toggleProject(project.id)
                  }
                },
                onNewChat: {
                  sidebarViewModel.requestNewChat(workingDirectory: project.workingDirectory)
                },
                onDelete: {
                  if let designSystem = project.designSystem {
                    requestDeleteDesignSystem(designSystem)
                  } else {
                    projectToDelete = project
                    showDeleteProjectConfirmation = true
                  }
                }
              )

              if project.isExpanded {
                VStack(alignment: .leading, spacing: 6) {
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
                          showDeleteSessionConfirmation = true
                        }
                      )
                      .padding(.leading, 6)
                      .transition(sessionRowTransition)
                    }
                  }
                }
                .transition(sessionListTransition)
              }
            }
            .id(projectHeaderScrollID(for: project.id))
            .transition(projectTransition)
          }
        }
        .animation(projectListAnimation, value: projectListAnimationValue)
      }

      if let projectDeletionError = sidebarViewModel.projectDeletionError {
        Text(projectDeletionError)
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var projectSearchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        .frame(width: 14)

      TextField("Filter by name", text: $sidebarViewModel.projectSearchText)
        .textFieldStyle(.plain)
        .font(EaselDesignSystem.Typography.interface(size: 13))
        .foregroundStyle(.primary)
        .accessibilityLabel("Filter designs by name")

      if sidebarViewModel.isFilteringProjects {
        Button {
          sidebarViewModel.projectSearchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
        .help("Clear search")
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 32)
    .background(
      EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private var canCreateProject: Bool {
    !sidebarViewModel.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var selectedContextDesignSystemName: String? {
    guard sidebarViewModel.selectedDesignSystem != .preset(.none) else { return nil }
    return sidebarViewModel.selectedDesignSystem.displayName
  }

  private var createButtonBackground: Color {
    if canCreateProject && !sidebarViewModel.isCreatingProject {
      return EaselDesignSystem.Palette.primaryAction(for: colorScheme)
    }

    return EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  private var createButtonForeground: Color {
    if canCreateProject && !sidebarViewModel.isCreatingProject {
      return EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme)
    }

    return EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }

  private var createButtonShortcutForeground: Color {
    if canCreateProject && !sidebarViewModel.isCreatingProject {
      return EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme).opacity(0.72)
    }

    return EaselDesignSystem.Palette.tertiaryText(for: colorScheme).opacity(0.72)
  }

  private var createButtonBorder: Color {
    if canCreateProject && !sidebarViewModel.isCreatingProject {
      return Color.clear
    }

    return EaselDesignSystem.Palette.border(for: colorScheme)
  }

  private var projectTransition: AnyTransition {
    .asymmetric(
      insertion: .opacity.combined(with: .move(edge: .top)),
      removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    )
  }

  private var sessionListTransition: AnyTransition {
    .asymmetric(
      insertion: .opacity.combined(with: .move(edge: .top)),
      removal: .opacity.combined(with: .move(edge: .top))
    )
  }

  private var sessionRowTransition: AnyTransition {
    .opacity.combined(with: .move(edge: .top))
  }

  private var projectListAnimation: Animation {
    .easeInOut(duration: 0.22)
  }

  private var projectListAnimationValue: [String] {
    sidebarViewModel.filteredProjectGroups.map { project in
      let sessionIDs = project.sessions.map(\.id).joined(separator: ",")
      return "\(project.id):\(project.isExpanded):\(sessionIDs)"
    }
  }

  private var projectGroupIDs: [String] {
    sidebarViewModel.filteredProjectGroups.map(\.id)
  }

  private var projectSearchEmptyMessage: String {
    let searchText = sidebarViewModel.projectSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return "No designs match \"\(searchText)\""
  }

  private func fulfillProjectHeaderScrollRequest(with scrollProxy: ScrollViewProxy) {
    guard let request = sidebarViewModel.projectHeaderScrollRequest,
          projectGroupIDs.contains(request.projectGroupID) else {
      return
    }

    Task { @MainActor in
      await Task.yield()

      let scrollAction = {
        scrollProxy.scrollTo(
          projectHeaderScrollID(for: request.projectGroupID),
          anchor: .top
        )
      }

      if reduceMotion {
        scrollAction()
      } else {
        withAnimation(projectListAnimation) {
          scrollAction()
        }
      }

      sidebarViewModel.clearProjectHeaderScrollRequest(request)
    }
  }

  private func projectHeaderScrollID(for projectID: String) -> ProjectHeaderScrollID {
    ProjectHeaderScrollID(projectID: projectID)
  }

  private func showCodebaseImporter() {
    isCodebaseImporterPresented = true
  }

  private var projectDeleteConfirmationMessage: String {
    guard let projectToDelete else {
      return "This project and its sessions will be deleted. This action cannot be undone."
    }

    let sessionCount = projectToDelete.sessions.count
    let sessionLabel = sessionCount == 1 ? "1 session" : "\(sessionCount) sessions"
    return "Delete \"\(projectToDelete.displayName)\"? " +
      "This will remove the project folder and \(sessionLabel). " +
      "This action cannot be undone."
  }

  private var canConfirmDesignSystemDeletion: Bool {
    guard let designSystemToDelete else { return false }
    return designSystemDeleteConfirmationName == designSystemToDelete.name
  }

  private var designSystemDeleteConfirmationMessage: String {
    guard let designSystemToDelete else {
      return "This design system will be deleted. This action cannot be undone."
    }

    return "Delete \"\(designSystemToDelete.name)\"? " +
      "This will remove the design system folder and related sessions. " +
      "Type or paste the design system name exactly to confirm."
  }

  private func requestDeleteDesignSystem(_ designSystem: EaselDesignSystemProfile) {
    designSystemToDelete = designSystem
    designSystemDeleteConfirmationName = ""
    showDeleteDesignSystemConfirmation = true
  }

  private func handleCreateProjectButton() {
    guard canCreateProject else { return }

    if sidebarViewModel.shouldRequestHighFidelityContext {
      sidebarViewModel.requestHighFidelityContext()
    } else if sidebarViewModel.shouldRequestWireframeContext {
      sidebarViewModel.requestWireframeContext()
    } else if sidebarViewModel.shouldRequestSlideDeckContext {
      sidebarViewModel.requestSlideDeckContext()
    } else {
      createProject(.empty)
    }
  }

  private func handleDesignSystemContextSelection() {
    sidebarViewModel.requestDesignSystemForHighFidelityContext()
  }

  private func createProject(_ context: HighFidelityProjectContext) {
    sidebarViewModel.clearHighFidelityContextRequest()
    sidebarViewModel.clearWireframeContextRequest()
    sidebarViewModel.clearSlideDeckContextRequest()
    Task {
      await sidebarViewModel.createProjectAndStartSession(context: context)
    }
  }

  private func resetDesignSystemDeleteConfirmation() {
    designSystemToDelete = nil
    designSystemDeleteConfirmationName = ""
  }
}

private struct ProjectHeaderScrollID: Hashable {
  let projectID: String
}
