//
//  DesignSystemBrowserView.swift
//  EaselChat
//

#if canImport(AppKit)
import AppKit
#endif
import EaselKit
import EaselDesignSystems
import SwiftUI

public struct DesignSystemBrowserView: View {
  @Bindable var sidebarViewModel: SidebarViewModel
  @Bindable var viewModel: DesignSystemBrowserViewModel
  let onCreateDesignSystem: () -> Void
  let onDone: () -> Void

  @Environment(\.openURL) private var openURL
  @Environment(\.colorScheme) private var colorScheme

  public init(
    sidebarViewModel: SidebarViewModel,
    viewModel: DesignSystemBrowserViewModel,
    onCreateDesignSystem: @escaping () -> Void,
    onDone: @escaping () -> Void
  ) {
    self.sidebarViewModel = sidebarViewModel
    self.viewModel = viewModel
    self.onCreateDesignSystem = onCreateDesignSystem
    self.onDone = onDone
  }

  public var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Choose design system")
          .font(EaselDesignSystem.Typography.interface(size: 20, weight: .semibold))

        Spacer()

        Button("Done", action: onDone)
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 20)
      .background(EaselDesignSystem.Palette.surface(for: colorScheme))

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      HStack(spacing: 0) {
        designSystemList
          .frame(width: 340)

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)

        designSystemDetail
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task {
      await viewModel.select(sidebarViewModel.selectedDesignSystem)
    }
    .onChange(of: sidebarViewModel.selectedDesignSystem) {
      Task {
        await viewModel.select(sidebarViewModel.selectedDesignSystem)
      }
    }
  }

  private var designSystemList: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(spacing: 0) {
        ForEach(sidebarViewModel.availableDesignSystemChoices) { choice in
          Button {
            sidebarViewModel.selectedDesignSystem = choice
          } label: {
            HStack(spacing: 14) {
              Image(systemName: sidebarViewModel.selectedDesignSystem.id == choice.id ? "checkmark.square.fill" : "square")
                .font(.title3.weight(.semibold))
                .foregroundStyle(sidebarViewModel.selectedDesignSystem.id == choice.id ? .primary : EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

              VStack(alignment: .leading, spacing: 4) {
                Text(choice.displayName)
                  .font(.title3.weight(.semibold))
                  .lineLimit(1)

                if choice.kind == .custom {
                  Text(choice.detail)
                    .font(.caption)
                    .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                    .lineLimit(2)
                }
              }

              Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sidebarViewModel.selectedDesignSystem.id == choice.id ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear)
          }
          .buttonStyle(.plain)

          Divider()
        }

        Button(action: onCreateDesignSystem) {
          VStack(alignment: .leading, spacing: 6) {
            Label("Set up a design system", systemImage: "plus")
              .font(.title3.weight(.semibold))

            Text("Import brand, code, and assets")
              .font(.callout)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
      }
      .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }

      Text("Selected design system is bound to this new project. You can change it before creating the project.")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding(18)
  }

  private var designSystemDetail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if let selectedChoice = viewModel.selectedChoice {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Browse \(selectedChoice.displayName)")
                .font(.system(size: 28, weight: .semibold, design: .serif))

              Text(viewModel.selectedCatalog?.summary ?? selectedChoice.detail)
                .font(.title3)
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }

            Spacer()

            HStack(spacing: 10) {
              if viewModel.canRegenerate {
                Button {
                  Task { await viewModel.regenerate() }
                } label: {
                  if viewModel.isRegenerating {
                    HStack(spacing: 6) {
                      ProgressView()
                        .controlSize(.small)
                      Text("Regenerating…")
                    }
                  } else {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                  }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRegenerating)
                .help("Re-import the stored Figma file using the latest catalog logic")
              }

              if let workingDirectory = selectedChoice.workingDirectory {
                Button("Open Folder", systemImage: "folder") {
                  openFolder(at: workingDirectory)
                }
                .buttonStyle(.bordered)
              }
            }
          }

          if viewModel.isLoadingCatalog {
            ProgressView("Loading catalog...")
              .frame(maxWidth: .infinity, minHeight: 180)
          } else if let errorMessage = viewModel.errorMessage {
            ProjectResourceErrorBanner(message: errorMessage)
          } else if let catalog = viewModel.selectedCatalog, catalog.hasReferenceContent {
            DesignSystemReferenceView(
              catalog: catalog,
              workingDirectory: selectedChoice.workingDirectory
            )
          } else if let catalog = viewModel.selectedCatalog, !catalog.componentGroups.isEmpty {
            VStack(spacing: 0) {
              ForEach(catalog.componentGroups) { group in
                DisclosureGroup {
                  VStack(alignment: .leading, spacing: 12) {
                    if group.items.isEmpty {
                      Text(group.summary)
                        .font(.callout)
                        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                    } else {
                      ForEach(group.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                          Text(item.title)
                            .font(.callout.weight(.semibold))
                          Text(item.summary)
                            .font(.callout)
                            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
                      }
                    }
                  }
                  .padding(.leading, 42)
                  .padding(.trailing, 18)
                  .padding(.bottom, 18)
                } label: {
                  VStack(alignment: .leading, spacing: 5) {
                    Text(group.title)
                      .font(.title3.weight(.semibold))
                    Text(group.summary)
                      .font(.callout)
                      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                  }
                  .padding(.vertical, 18)
                }
                .padding(.horizontal, 22)

                Divider()
              }
            }
            .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            }
          } else if let catalog = viewModel.selectedCatalog, catalog.generatedAt != nil {
            emptyGeneratedCatalogState(for: catalog)
          } else if selectedChoice.preset == EaselDesignSystemPreset.none {
            VStack(alignment: .leading, spacing: 10) {
              Label("No design system selected", systemImage: "square.dashed")
                .font(.title3.weight(.semibold))
              Text("The prototype prompt will not reference a reusable design system. Codex will create an original product UI for the request.")
                .font(.callout)
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            }
          } else {
            VStack(alignment: .leading, spacing: 10) {
              Label("Catalog pending", systemImage: "hourglass")
                .font(.title3.weight(.semibold))
              Text("The component list will appear here after Codex creates `.easel/catalog.json` for this design system.")
                .font(.callout)
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func emptyGeneratedCatalogState(for catalog: EaselDesignSystemCatalog) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(emptyGeneratedCatalogTitle(for: catalog), systemImage: emptyGeneratedCatalogSystemImage(for: catalog))
        .font(.title3.weight(.semibold))
      Text(catalog.summary)
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private func emptyGeneratedCatalogTitle(for catalog: EaselDesignSystemCatalog) -> String {
    if catalog.summary.localizedCaseInsensitiveContains("could not be parsed") {
      return "Catalog import failed"
    }
    return "No component catalog extracted"
  }

  private func emptyGeneratedCatalogSystemImage(for catalog: EaselDesignSystemCatalog) -> String {
    if catalog.summary.localizedCaseInsensitiveContains("could not be parsed") {
      return "exclamationmark.triangle"
    }
    return "doc.text.magnifyingglass"
  }

  private func openFolder(at path: String) {
    let folderURL = URL(fileURLWithPath: path, isDirectory: true)
#if canImport(AppKit)
    if NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path) {
      return
    }
#endif
    openURL(folderURL)
  }
}
