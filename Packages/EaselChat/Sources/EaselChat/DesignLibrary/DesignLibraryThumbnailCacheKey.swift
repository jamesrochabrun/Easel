//
//  DesignLibraryThumbnailCacheKey.swift
//  EaselChat
//

import Foundation

struct DesignLibraryThumbnailCacheKey: Hashable {
  let itemID: String
  let workingDirectory: String
  let kind: DesignLibraryItemKind
  let modificationDate: Date?
  let byteCount: Int?

  init(item: DesignLibraryItem) {
    self.itemID = item.id
    self.workingDirectory = item.workingDirectory
    self.kind = item.kind
    self.modificationDate = item.previewFile?.modificationDate
    self.byteCount = item.previewFile?.byteCount
  }
}
