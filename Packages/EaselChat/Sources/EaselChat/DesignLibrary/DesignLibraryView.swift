//
//  DesignLibraryView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

public struct DesignLibraryView: View {
  @Bindable var viewModel: DesignLibraryViewModel
  let onOpenSelection: (DesignLibrarySelection) -> Void
  private let showsHeader: Bool
  private let onCreateDesign: (() -> Void)?

  @State private var thumbnailCache = DesignLibraryThumbnailCache()
  @State private var designSystemPendingDeletion: EaselDesignSystemProfile?
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
          itemCount: viewModel.items.count,
          isLoading: viewModel.isLoading,
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
          } else {
            DesignLibraryGridView(
              items: viewModel.items,
              thumbnailCache: thumbnailCache,
              onOpenSelection: onOpenSelection,
              onRequestDeleteDesignSystem: { designSystemPendingDeletion = $0 }
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
    .sheet(item: $designSystemPendingDeletion) { profile in
      DeleteDesignSystemConfirmationView(
        profile: profile,
        onCancel: { designSystemPendingDeletion = nil },
        onConfirm: {
          designSystemPendingDeletion = nil
          Task { await viewModel.deleteDesignSystem(profile) }
        }
      )
    }
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
