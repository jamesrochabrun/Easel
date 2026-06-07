//
//  DesignSystemBrowserView.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

public struct DesignSystemBrowserView: View {
  @Bindable var sidebarViewModel: SidebarViewModel
  @Bindable var viewModel: DesignSystemBrowserViewModel
  let onCreateDesignSystem: () -> Void
  let onUseStartingPoint: (EaselDesignSystemStartingPoint) -> Void
  let onDone: () -> Void

  @Environment(\.openURL) private var openURL
  @Environment(\.colorScheme) private var colorScheme

  public init(
    sidebarViewModel: SidebarViewModel,
    viewModel: DesignSystemBrowserViewModel,
    onCreateDesignSystem: @escaping () -> Void,
    onUseStartingPoint: @escaping (EaselDesignSystemStartingPoint) -> Void,
    onDone: @escaping () -> Void
  ) {
    self.sidebarViewModel = sidebarViewModel
    self.viewModel = viewModel
    self.onCreateDesignSystem = onCreateDesignSystem
    self.onUseStartingPoint = onUseStartingPoint
    self.onDone = onDone
  }

  public var body: some View {
    VStack(spacing: 0) {
      header

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      HStack(spacing: 0) {
        sidebar
          .frame(width: 340)

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)

        detail
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task {
      await selectInitialDesignSystem()
    }
    .onChange(of: sidebarViewModel.selectedDesignSystems) {
      Task {
        await reconcileFocusedDesignSystem()
      }
    }
  }

  private var header: some View {
    HStack {
      Text("Choose design systems")
        .font(EaselDesignSystem.Typography.interface(size: 20, weight: .semibold))

      Spacer()

      Button("Done", action: onDone)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Selected")
          .font(.callout.weight(.semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        List {
          ForEach(Array(sidebarViewModel.selectedDesignSystems.enumerated()), id: \.element.id) { index, choice in
            DesignSystemSelectedChoiceRow(
              choice: choice,
              isFocused: viewModel.selectedChoice?.id == choice.id,
              isHighestPrecedence: index == 0,
              onSelect: {
                Task { await viewModel.select(choice) }
              },
              onRemove: {
                sidebarViewModel.removeDesignSystem(choice)
              },
              onMakeHighestPrecedence: {
                sidebarViewModel.makeHighestPrecedenceDesignSystem(choice)
              }
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
          }
          .onMove(perform: sidebarViewModel.moveSelectedDesignSystems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 104, maxHeight: 178)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Available")
          .font(.callout.weight(.semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        VStack(spacing: 0) {
          Button(action: onCreateDesignSystem) {
            VStack(alignment: .leading, spacing: 6) {
              Label("Set up a design system", systemImage: "plus")
                .font(.title3.weight(.semibold))

              Text("Import brand, code, and assets")
                .font(.callout)
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
          }
          .buttonStyle(.plain)

          ForEach(sidebarViewModel.unselectedDesignSystemChoices) { choice in
            Divider()

            DesignSystemAvailableChoiceRow(choice: choice) {
              if choice.isNone {
                sidebarViewModel.selectDesignSystem(choice)
              } else {
                sidebarViewModel.addDesignSystem(choice)
              }
              Task { await viewModel.select(choice) }
            }
          }
        }
        .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }

      Text("Drag selected design systems to reorder - the one at the top takes precedence.")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding(18)
  }

  private var detail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if let selectedChoice = viewModel.selectedChoice {
          detailHeader(for: selectedChoice)

          if viewModel.isLoadingCatalog {
            ProgressView("Loading catalog...")
              .frame(maxWidth: .infinity, minHeight: 180)
          } else if let errorMessage = viewModel.errorMessage {
            ProjectResourceErrorBanner(message: errorMessage)
          } else if let catalog = viewModel.selectedCatalog, !catalog.browsableGroups.isEmpty {
            VStack(spacing: 0) {
              ForEach(catalog.browsableGroups) { group in
                DesignSystemCatalogGroupView(
                  designSystem: selectedChoice,
                  catalog: catalog,
                  group: group,
                  previewURL: viewModel.previewURL(for: group.previewPath),
                  onUseStartingPoint: onUseStartingPoint
                )

                Divider()
              }
            }
            .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            }
          } else if selectedChoice.preset == EaselDesignSystemPreset.none {
            emptyState(
              title: "No design system selected",
              systemImage: "square.dashed",
              message: "The prototype prompt will not reference a reusable design system. Codex will create an original product UI for the request."
            )
          } else {
            emptyState(
              title: "Catalog pending",
              systemImage: "hourglass",
              message: "The component list will appear here after Codex creates `.easel/catalog.json` for this design system."
            )
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func detailHeader(for selectedChoice: EaselDesignSystemChoice) -> some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Browse \(selectedChoice.displayName)")
          .font(.system(size: 28, weight: .semibold, design: .serif))

        Text(viewModel.selectedCatalog?.summary ?? selectedChoice.detail)
          .font(.title3)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      if let workingDirectory = selectedChoice.workingDirectory {
        Button("Open Folder", systemImage: "folder") {
          openURL(URL(fileURLWithPath: workingDirectory))
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func emptyState(title: String, systemImage: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.title3.weight(.semibold))
      Text(message)
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private func selectInitialDesignSystem() async {
    await viewModel.select(sidebarViewModel.selectedDesignSystem)
  }

  private func reconcileFocusedDesignSystem() async {
    guard let selectedChoice = viewModel.selectedChoice,
          sidebarViewModel.selectedDesignSystems.contains(where: { $0.id == selectedChoice.id }) else {
      await selectInitialDesignSystem()
      return
    }
  }
}
