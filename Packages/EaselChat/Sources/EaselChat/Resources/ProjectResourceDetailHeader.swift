//
//  ProjectResourceDetailHeader.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceDetailHeader: View {
  let item: ProjectResourcePanelItem
  let onBack: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onBack) {
        Label("Back", systemImage: "chevron.left")
          .labelStyle(.iconOnly)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
        .buttonStyle(.plain)
        .help("Back to files")

      ProjectFileThumbnailView(
        fileURL: item.fileURL,
        kind: item.kind,
        targetSize: CGSize(width: 52, height: 52),
        cornerRadius: 8,
        contentMode: .fit
      )
      .frame(width: 52, height: 52)

      VStack(alignment: .leading, spacing: 5) {
        Text(item.fileName)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)

        Text(item.relativePath)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)

        ProjectResourceFileMetadataView(item: item)
      }

      Spacer(minLength: 12)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
