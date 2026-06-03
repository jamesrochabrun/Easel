//
//  ProjectResourceVisualPreview.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceVisualPreview: View {
  let item: ProjectResourcePanelItem

  var body: some View {
    VStack(spacing: 14) {
      ProjectFileThumbnailView(
        fileURL: item.fileURL,
        kind: item.kind,
        targetSize: CGSize(width: 980, height: 720),
        cornerRadius: 8,
        contentMode: .fit
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
