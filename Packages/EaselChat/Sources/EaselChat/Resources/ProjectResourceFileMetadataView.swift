//
//  ProjectResourceFileMetadataView.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceFileMetadataView: View {
  let item: ProjectResourcePanelItem

  var body: some View {
    HStack(spacing: 6) {
      Text(item.sourceDisplayName)
      Text(item.kind.displayName)
      Text(formattedByteCount)

      if let modifiedAt = item.modifiedAt {
        Text(modifiedAt, style: .date)
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }

  private var formattedByteCount: String {
    ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file)
  }
}
