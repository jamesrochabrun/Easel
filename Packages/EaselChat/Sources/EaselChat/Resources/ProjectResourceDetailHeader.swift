//
//  ProjectResourceDetailHeader.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceDetailHeader: View {
  let item: ProjectResourcePanelItem
  let onOpen: () -> Void
  let onReveal: () -> Void
  let onClose: () -> Void

  var body: some View {
    HStack(spacing: 12) {
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

      Button("Reveal", systemImage: "folder", action: onReveal)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .help("Reveal in Finder")

      Button("Open", systemImage: "arrow.up.right.square", action: onOpen)
        .buttonStyle(.bordered)
        .controlSize(.small)

      Button("Close preview", systemImage: "xmark", action: onClose)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .help("Close preview")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
