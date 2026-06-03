//
//  ProjectFileThumbnailGenerator.swift
//  EaselChat
//

import CoreGraphics
import Foundation
import QuickLookThumbnailing

enum ProjectFileThumbnailGenerator {
  static func thumbnail(
    for fileURL: URL,
    size: CGSize,
    scale: CGFloat
  ) async throws -> CGImage {
    let request = QLThumbnailGenerator.Request(
      fileAt: fileURL,
      size: size,
      scale: scale,
      representationTypes: .all
    )

    return try await withCheckedThrowingContinuation { continuation in
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
        if let cgImage = representation?.cgImage {
          continuation.resume(returning: cgImage)
        } else if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(throwing: CocoaError(.fileReadUnknown))
        }
      }
    }
  }
}
