//
//  ProjectResourcePreviewContentView.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourcePreviewContentView: View {
  let item: ProjectResourcePanelItem
  let preview: ProjectResourcePreview?
  let isLoading: Bool
  let isSaving: Bool
  let onSaveText: (String) -> Void

  var body: some View {
    Group {
      if isLoading {
        ProgressView("Loading preview...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let preview {
        switch preview.content {
        case let .text(text):
          ProjectResourceTextPreview(
            item: item,
            text: text,
            isSaving: isSaving,
            onSave: onSaveText
          )
        case .visual:
          ProjectResourceVisualPreview(item: item)
        case let .unavailable(message):
          ProjectResourceUnavailablePreview(item: item, message: message)
        }
      } else {
        ProjectResourceVisualPreview(item: item)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
