//
//  APIImageContentConverter.swift
//  ClaudeCodeUI
//

import AgentHarness
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts the `"Analyze this image: <path>"` marker lines that
/// `AttachmentProcessor.formatImagePathsForMessage` injects into outgoing
/// prompts into real image content blocks for vision-capable API providers.
///
/// The prompt text keeps the marker lines (so non-vision models still see the
/// path and can Read around it); blocks are additive. Files that are missing
/// or unreadable are skipped silently. Pure and stateless.
enum APIImageContentConverter {

  static let markerPrefix = "Analyze this image: "
  static let maxPixelSize = 1_568
  static let jpegQuality = 0.85

  /// - Returns: the unchanged prompt text plus one `imageDataURL` block per
  ///   readable image referenced by a marker line, in prompt order.
  static func contentBlocks(for prompt: String) -> [AgentContentBlock] {
    var blocks: [AgentContentBlock] = [.text(prompt)]
    for path in imagePaths(in: prompt) {
      if let dataURL = jpegDataURL(forImageAt: URL(fileURLWithPath: path)) {
        blocks.append(.imageDataURL(dataURL))
      }
    }
    return blocks
  }

  /// Marker-referenced image paths, in order of appearance.
  static func imagePaths(in prompt: String) -> [String] {
    prompt
      .components(separatedBy: .newlines)
      .compactMap { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(markerPrefix) else { return nil }
        let path = String(trimmed.dropFirst(markerPrefix.count)).trimmingCharacters(in: .whitespaces)
        return path.isEmpty ? nil : path
      }
  }

  /// Loads, downsizes (longest side ≤ `maxPixelSize`, honoring orientation),
  /// and re-encodes the image as a base64 JPEG data URL. Returns nil for
  /// missing, unreadable, or non-image files.
  static func jpegDataURL(forImageAt url: URL) -> String? {
    guard FileManager.default.fileExists(atPath: url.path),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) > 0
    else { return nil }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
      return nil
    }

    let encoded = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      encoded,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else { return nil }

    CGImageDestinationAddImage(
      destination,
      image,
      [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else { return nil }

    return "data:image/jpeg;base64,\((encoded as Data).base64EncodedString())"
  }
}
