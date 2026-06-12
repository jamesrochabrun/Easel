//
//  DesignLibraryThumbnailView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

struct DesignLibraryThumbnailView: View {
  let item: DesignLibraryItem
  @Bindable var thumbnailCache: DesignLibraryThumbnailCache
  @Bindable var paletteCache: DesignLibraryPaletteCache

  @Environment(\.colorScheme) private var colorScheme

  /// Design systems show their color palette instead of a rendered "site"
  /// preview. The palette loads asynchronously, so this is non-nil only once
  /// the catalog has been read and contained usable colors.
  private var designSystemPalette: [EaselDesignSystemColorToken]? {
    guard item.kind == .designSystem else { return nil }
    guard let colors = paletteCache.palette(for: item.workingDirectory), !colors.isEmpty else {
      return nil
    }
    return colors
  }

  var body: some View {
    let key = DesignLibraryThumbnailCacheKey(item: item)

    ZStack {
      if let palette = designSystemPalette {
        DesignLibraryPaletteThumbnailView(colors: palette)
      } else if let image = thumbnailCache.image(for: key) {
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
      // Projects and slide decks render a live snapshot of their preview file.
      // Design systems use their palette instead, so they skip the web render.
      if item.kind != .designSystem,
         let previewFile = item.previewFile,
         thumbnailCache.shouldRender(key) {
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
    .task(id: item.workingDirectory) {
      if item.kind == .designSystem {
        paletteCache.ensureLoaded(for: item.workingDirectory)
      }
    }
  }
}
