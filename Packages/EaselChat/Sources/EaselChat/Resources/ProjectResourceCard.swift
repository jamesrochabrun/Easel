//
//  ProjectResourceCard.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceCard: View {
  let resource: ProjectResource
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      VStack(alignment: .leading, spacing: 10) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(tint.opacity(0.16))

          Image(systemName: resource.kind.systemImage)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(tint)
        }
        .frame(height: 118)

        VStack(alignment: .leading, spacing: 4) {
          Text(resource.fileName)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(minHeight: 38, alignment: .topLeading)

          HStack(spacing: 6) {
            Text(resource.kind.displayName)
            Text(formattedByteCount)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(.quaternary, lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .help("Open \(resource.fileName)")
  }

  private var tint: Color {
    switch resource.kind {
    case .image:
      return Color(red: 0.12, green: 0.55, blue: 0.46)
    case .video:
      return Color(red: 0.25, green: 0.42, blue: 0.82)
    case .audio:
      return Color(red: 0.76, green: 0.44, blue: 0.11)
    case .pdf:
      return Color(red: 0.80, green: 0.18, blue: 0.16)
    case .document:
      return Color(red: 0.45, green: 0.36, blue: 0.72)
    case .archive:
      return Color(red: 0.45, green: 0.42, blue: 0.35)
    case .other:
      return Color.secondary
    }
  }

  private var formattedByteCount: String {
    ByteCountFormatter.string(fromByteCount: resource.byteCount, countStyle: .file)
  }
}
