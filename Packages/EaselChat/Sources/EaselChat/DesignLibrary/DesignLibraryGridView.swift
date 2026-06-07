//
//  DesignLibraryGridView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

struct DesignLibraryGridView: View {
  let items: [DesignLibraryItem]
  @Bindable var thumbnailCache: DesignLibraryThumbnailCache
  let onOpenSelection: (DesignLibrarySelection) -> Void
  let onRequestDeleteDesignSystem: (EaselDesignSystemProfile) -> Void

  /// The grid renders its first wave of cells together, so those stagger into
  /// view. Once that wave has played, cells revealed later (while scrolling)
  /// should fade in immediately instead of waiting for a stagger slot.
  @State private var isStaggeringInitialReveal = true

  private let columns = [
    GridItem(.adaptive(minimum: 280, maximum: 430), spacing: 24, alignment: .top)
  ]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        if let selection = item.selection {
          DesignLibraryGridCellButton(
            item: item,
            selection: selection,
            revealDelay: isStaggeringInitialReveal ? Self.staggerDelay(forCellAt: index) : 0,
            thumbnailCache: thumbnailCache,
            onOpenSelection: onOpenSelection,
            onRequestDeleteDesignSystem: onRequestDeleteDesignSystem
          )
        }
      }
    }
    .padding(24)
    .task {
      // Stagger only the initial wave; afterwards reveal scrolled-in cells
      // without delay so scrolling never feels gated by the animation.
      try? await Task.sleep(for: .milliseconds(700))
      isStaggeringInitialReveal = false
    }
  }

  private static func staggerDelay(forCellAt index: Int) -> Double {
    min(Double(index) * 0.035, 0.35)
  }
}

private struct DesignLibraryGridCellButton: View {
  let item: DesignLibraryItem
  let selection: DesignLibrarySelection
  let revealDelay: Double
  @Bindable var thumbnailCache: DesignLibraryThumbnailCache
  let onOpenSelection: (DesignLibrarySelection) -> Void
  let onRequestDeleteDesignSystem: (EaselDesignSystemProfile) -> Void

  @State private var isVisible = false
  @State private var isHovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Button {
        onOpenSelection(selection)
      } label: {
        DesignLibraryCardView(item: item, thumbnailCache: thumbnailCache)
      }
      .buttonStyle(.plain)
      .help("Open \(item.title)")
      .accessibilityLabel(accessibilityLabel(for: item))

      if item.designSystem != nil {
        menuButton
          .opacity(isHovering ? 1 : 0.65)
      }
    }
    .opacity(isVisible ? 1 : 0)
    .offset(y: isVisible ? 0 : 6)
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
    }
    .contextMenu { deleteMenuItems }
    .onAppear(perform: reveal)
  }

  @ViewBuilder
  private var deleteMenuItems: some View {
    if let designSystem = item.designSystem {
      Button("Delete Design System…", systemImage: "trash", role: .destructive) {
        onRequestDeleteDesignSystem(designSystem)
      }
    }
  }

  private var menuButton: some View {
    Menu {
      deleteMenuItems
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .frame(width: 26, height: 26)
        .background(.regularMaterial, in: Circle())
        .overlay {
          Circle().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
        .contentShape(Circle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .padding(10)
    .help("Manage \(item.title)")
  }

  private func reveal() {
    guard !isVisible else { return }

    if reduceMotion {
      isVisible = true
      return
    }

    // Defer the flip one runloop tick so SwiftUI commits the hidden state
    // before animating it. Flipping synchronously inside `onAppear` collapses
    // the change into the cell's insertion transaction, so no fade is rendered.
    Task { @MainActor in
      withAnimation(.easeOut(duration: 0.32).delay(revealDelay)) {
        isVisible = true
      }
    }
  }

  private func accessibilityLabel(for item: DesignLibraryItem) -> String {
    "\(item.title), \(item.kind.displayName)"
  }
}
