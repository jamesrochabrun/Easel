//
//  ProjectResourceDetailView.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceDetailView: View {
  let item: ProjectResourcePanelItem?
  let preview: ProjectResourcePreview?
  let isLoading: Bool
  let isSaving: Bool
  let onOpen: (ProjectResourcePanelItem) -> Void
  let onReveal: (ProjectResourcePanelItem) -> Void
  let onSaveText: (ProjectResourcePanelItem, String) -> Void
  let onClose: () -> Void

  var body: some View {
    Group {
      if let item {
        VStack(spacing: 0) {
          ProjectResourceDetailHeader(
            item: item,
            onOpen: {
              onOpen(item)
            },
            onReveal: {
              onReveal(item)
            },
            onClose: onClose
          )

          Rectangle()
            .fill(.quaternary)
            .frame(height: 1)

          ProjectResourcePreviewContentView(
            item: item,
            preview: preview,
            isLoading: isLoading,
            isSaving: isSaving,
            onSaveText: { text in
              onSaveText(item, text)
            }
          )
        }
      } else {
        ProjectResourceSelectionEmptyState()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.background)
  }
}
