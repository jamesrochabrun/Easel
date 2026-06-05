//
//  DesignLibraryThumbnailView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryThumbnailView: View {
  let item: DesignLibraryItem
  @Bindable var thumbnailCache: DesignLibraryThumbnailCache

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let key = DesignLibraryThumbnailCacheKey(item: item)

    ZStack {
      if let image = thumbnailCache.image(for: key) {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(16 / 9, contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      } else {
        DesignLibraryThumbnailPlaceholderView(item: item)
      }
    }
    .aspectRatio(16 / 9, contentMode: .fit)
    .frame(maxWidth: .infinity)
    .background(EaselDesignSystem.Palette.surfaceElevated(for: colorScheme))
    .overlay {
      if let previewFile = item.previewFile, thumbnailCache.shouldRender(key) {
        DesignLibraryThumbnailRenderer(
          previewFile: previewFile,
          kind: item.kind,
          cacheKey: key,
          onRendered: { renderedKey, image in
            thumbnailCache.store(image, for: renderedKey)
          },
          onFailed: { failedKey in
            thumbnailCache.markFailed(failedKey)
          }
        )
        .frame(
          width: DesignLibraryThumbnailMetrics.renderSize.width,
          height: DesignLibraryThumbnailMetrics.renderSize.height
        )
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
    }
    .clipped()
  }
}
