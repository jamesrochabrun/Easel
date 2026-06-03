//
//  ProjectResourceUnavailablePreview.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceUnavailablePreview: View {
  let item: ProjectResourcePanelItem
  let message: String

  var body: some View {
    VStack(spacing: 14) {
      ProjectFileThumbnailView(
        fileURL: item.fileURL,
        kind: item.kind,
        targetSize: CGSize(width: 280, height: 200),
        cornerRadius: 8,
        contentMode: .fit
      )
      .frame(width: 280, height: 200)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
