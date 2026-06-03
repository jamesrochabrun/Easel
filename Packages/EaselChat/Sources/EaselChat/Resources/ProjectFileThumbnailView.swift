//
//  ProjectFileThumbnailView.swift
//  EaselChat
//

import CoreGraphics
import QuickLookThumbnailing
import SwiftUI

struct ProjectFileThumbnailView: View {
  @Environment(\.displayScale) private var displayScale

  let fileURL: URL
  let kind: ProjectResource.Kind
  let targetSize: CGSize
  let cornerRadius: CGFloat
  let contentMode: ContentMode

  @State private var thumbnail: CGImage?
  @State private var didFailToLoadThumbnail = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(tint.opacity(0.16))

        if let thumbnail {
          Image(decorative: thumbnail, scale: displayScale)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        } else {
          Image(systemName: kind.systemImage)
            .font(.system(size: fallbackIconSize, weight: .medium))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(.quaternary, lineWidth: 1)
    }
    .task(id: thumbnailTaskID) {
      await loadThumbnail(for: thumbnailTaskID)
    }
  }

  private var thumbnailTaskID: String {
    "\(fileURL.path)|\(Int(targetSize.width))|\(Int(targetSize.height))|\(displayScale)"
  }

  private var tint: Color {
    switch kind {
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

  private var fallbackIconSize: CGFloat {
    min(max(min(targetSize.width, targetSize.height) * 0.32, 18), 46)
  }

  private func loadThumbnail(for taskID: String) async {
    thumbnail = nil
    didFailToLoadThumbnail = false

    do {
      let loadedThumbnail = try await ProjectFileThumbnailGenerator.thumbnail(
        for: fileURL,
        size: targetSize,
        scale: displayScale
      )
      guard thumbnailTaskID == taskID else { return }

      thumbnail = loadedThumbnail
    } catch {
      guard thumbnailTaskID == taskID else { return }

      didFailToLoadThumbnail = true
    }
  }
}
