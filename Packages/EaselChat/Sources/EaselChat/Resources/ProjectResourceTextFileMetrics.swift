//
//  ProjectResourceTextFileMetrics.swift
//  EaselChat
//

import Foundation

struct ProjectResourceTextFileMetrics: Equatable, Sendable {
  let byteCount: Int
  let lineCount: Int
  let maxLineByteCount: Int

  static func metrics(forUTF8Data data: Data) -> ProjectResourceTextFileMetrics {
    metrics(forUTF8Bytes: data, byteCount: data.count)
  }

  static func metrics(for content: String) -> ProjectResourceTextFileMetrics {
    metrics(forUTF8Bytes: content.utf8, byteCount: content.utf8.count)
  }

  private static func metrics<Bytes: Sequence>(
    forUTF8Bytes bytes: Bytes,
    byteCount: Int
  ) -> ProjectResourceTextFileMetrics where Bytes.Element == UInt8 {
    guard byteCount > 0 else {
      return ProjectResourceTextFileMetrics(byteCount: 0, lineCount: 0, maxLineByteCount: 0)
    }

    var lineCount = 1
    var currentLineByteCount = 0
    var maxLineByteCount = 0

    for byte in bytes {
      if byte == 0x0A {
        maxLineByteCount = max(maxLineByteCount, currentLineByteCount)
        currentLineByteCount = 0
        lineCount += 1
      } else {
        currentLineByteCount += 1
      }
    }

    maxLineByteCount = max(maxLineByteCount, currentLineByteCount)
    return ProjectResourceTextFileMetrics(
      byteCount: byteCount,
      lineCount: lineCount,
      maxLineByteCount: maxLineByteCount
    )
  }
}
