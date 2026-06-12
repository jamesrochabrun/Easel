//
//  ProjectResourcesContentView.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourcesContentView: View {
  let resources: [ProjectResource]
  let projectStructureSections: [ProjectStructureSection]
  let selectedItem: ProjectResourcePanelItem?
  let selectedPreview: ProjectResourcePreview?
  let isPreviewLoading: Bool
  let isSavingPreview: Bool
  let onSelect: (ProjectResourcePanelItem) -> Void
  let onSaveText: (ProjectResourcePanelItem, String) -> Void
  let onBack: () -> Void
  let onDelete: (ProjectResourcePanelItem) -> Void

  var body: some View {
    ZStack {
      if let selectedItem {
        ProjectResourceDetailView(
          item: selectedItem,
          preview: selectedPreview,
          isLoading: isPreviewLoading,
          isSaving: isSavingPreview,
          onSaveText: onSaveText,
          onBack: onBack
        )
        .transition(detailTransition)
      } else {
        ProjectResourceLibraryView(
          resources: resources,
          projectStructureSections: projectStructureSections,
          selectedItem: selectedItem,
          columns: columns,
          onSelect: onSelect,
          onDelete: onDelete
        )
        .transition(libraryTransition)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .animation(.snappy(duration: 0.28, extraBounce: 0), value: selectedItem?.id)
  }

  private var columns: [GridItem] {
    [
      GridItem(
        .adaptive(
          minimum: 240,
          maximum: 320
        ),
        spacing: 16
      )
    ]
  }

  private var detailTransition: AnyTransition {
    .asymmetric(
      insertion: .move(edge: .trailing).combined(with: .opacity),
      removal: .move(edge: .trailing).combined(with: .opacity)
    )
  }

  private var libraryTransition: AnyTransition {
    .asymmetric(
      insertion: .move(edge: .leading).combined(with: .opacity),
      removal: .move(edge: .leading).combined(with: .opacity)
    )
  }
}
