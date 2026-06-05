//
//  DesignLibraryThumbnailCache.swift
//  EaselChat
//

import AppKit
import Foundation

@Observable @MainActor
final class DesignLibraryThumbnailCache {
  private var imagesByKey: [DesignLibraryThumbnailCacheKey: NSImage] = [:]
  private var failedKeys: Set<DesignLibraryThumbnailCacheKey> = []

  func image(for key: DesignLibraryThumbnailCacheKey) -> NSImage? {
    imagesByKey[key]
  }

  func shouldRender(_ key: DesignLibraryThumbnailCacheKey) -> Bool {
    imagesByKey[key] == nil && !failedKeys.contains(key)
  }

  func store(_ image: NSImage, for key: DesignLibraryThumbnailCacheKey) {
    failedKeys.remove(key)
    imagesByKey[key] = image
  }

  func markFailed(_ key: DesignLibraryThumbnailCacheKey) {
    failedKeys.insert(key)
  }
}
