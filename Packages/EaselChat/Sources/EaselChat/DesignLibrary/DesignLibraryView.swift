//
//  DesignLibraryView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

public struct DesignLibraryView: View {
  @Bindable var viewModel: DesignLibraryViewModel
  let onOpenSelection: (DesignLibrarySelection) -> Void
  private let showsHeader: Bool
  private let onCreateDesign: (() -> Void)?

  @State private var thumbnailCache = DesignLibraryThumbnailCache()
  @State private var paletteCache = DesignLibraryPaletteCache()
  @Environment(\.colorScheme) private var colorScheme

  public init(
    viewModel: DesignLibraryViewModel,
    showsHeader: Bool = true,
    onCreateDesign: (() -> Void)? = nil,
    onOpenSelection: @escaping (DesignLibrarySelection) -> Void
  ) {
    self.viewModel = viewModel
    self.showsHeader = showsHeader
    self.onCreateDesign = onCreateDesign
    self.onOpenSelection = onOpenSelection
  }

  public var body: some View {
    VStack(spacing: 0) {
      if showsHeader {
        DesignLibraryHeaderView(
          itemCount: viewModel.visibleItems.count,
          isLoading: viewModel.isLoading,
          showsFilters: !viewModel.items.isEmpty,
          selectedKinds: viewModel.selectedKinds,
          kindCounts: kindCounts,
          onToggleKind: { viewModel.toggleKind($0) },
          onRefresh: refresh
        )

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(height: 1)
      }

      ScrollView {
        VStack(spacing: 0) {
          if let errorMessage = viewModel.errorMessage {
            DesignLibraryErrorBanner(message: errorMessage)
              .padding(.horizontal, 24)
              .padding(.top, 18)
          }

          if viewModel.items.isEmpty {
            emptyState
          } else if viewModel.visibleItems.isEmpty {
            filteredEmptyState
          } else {
            DesignLibraryGridView(
              items: viewModel.visibleItems,
              thumbnailCache: thumbnailCache,
              paletteCache: paletteCache,
              onOpenSelection: onOpenSelection
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .scrollContentBackground(.visible)
      .overlay {
        if viewModel.isLoading && viewModel.items.isEmpty {
          ProgressView("Loading designs...")
            .controlSize(.small)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
        }
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task {
      await refresh()
    }
  }

  private var kindCounts: [DesignLibraryItemKind: Int] {
    Dictionary(
      uniqueKeysWithValues: DesignLibraryItemKind.allCases.map { kind in
        (kind, viewModel.itemCount(for: kind))
      }
    )
  }

  @ViewBuilder
  private var filteredEmptyState: some View {
    ContentUnavailableView {
      Label("No matching designs", systemImage: "line.3.horizontal.decrease.circle")
    } description: {
      Text("No designs match the selected filters.")
    } actions: {
      Button("Show All Designs") {
        viewModel.selectAllKinds()
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
    }
    .frame(maxWidth: .infinity, minHeight: 360)
    .padding(24)
  }

  @ViewBuilder
  private var emptyState: some View {
    if let onCreateDesign {
      ContentUnavailableView {
        Label("No designs", systemImage: "square.grid.2x2")
      } description: {
        Text("Create a prototype, slide deck, or design system to see it here.")
      } actions: {
        Button("Show Create Controls", systemImage: "sidebar.left", action: onCreateDesign)
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      }
      .frame(maxWidth: .infinity, minHeight: 360)
      .padding(24)
    } else {
      ContentUnavailableView(
        "No designs",
        systemImage: "square.grid.2x2",
        description: Text("Create a prototype, slide deck, or design system to see it here.")
      )
      .frame(maxWidth: .infinity, minHeight: 360)
      .padding(24)
    }
  }

  private func refresh() async {
    await viewModel.refresh()
  }
}
