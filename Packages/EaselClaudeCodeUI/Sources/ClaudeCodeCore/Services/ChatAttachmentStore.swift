//
//  ChatAttachmentStore.swift
//  ClaudeCodeUI
//

import Foundation

/// Durable, app-owned storage for chat attachments.
///
/// Dragged screenshots live in screencaptureui's purgeable container
/// (`/var/folders/.../TemporaryItems/NSIRD_screencaptureui_*`) and are
/// reaped moments after the drag ends — so anything temporary must be
/// copied here at drop time. The stable path is what gets embedded in the
/// prompt (the CLI reads it later), persisted with the message, and
/// re-read by the feed to render thumbnails after a session reload.
// @unchecked: FileManager is documented thread-safe for these operations.
public struct ChatAttachmentStore: @unchecked Sendable {
  private let fileManager: FileManager
  public let rootDirectory: URL

  public init(
    fileManager: FileManager = .default,
    rootDirectory: URL? = nil
  ) {
    self.fileManager = fileManager
    self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
  }

  public static func defaultRootDirectory(fileManager: FileManager = .default) -> URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.temporaryDirectory
    return base
      .appendingPathComponent("ClaudeCodeUI", isDirectory: true)
      .appendingPathComponent("Attachments", isDirectory: true)
  }

  /// Copies a file into the store under a fresh per-import directory
  /// (`<root>/<UUID>/<fileName>`), so same-named drops never collide.
  /// Returns nil when the source is unreadable.
  public func importCopy(of url: URL) -> URL? {
    let destination = destinationURL(fileName: url.lastPathComponent)

    do {
      try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileManager.copyItem(at: url, to: destination)
      return destination
    } catch {
      return nil
    }
  }

  /// Writes raw bytes (an image dragged as data, with no backing file)
  /// into the store. Returns nil on failure.
  public func write(data: Data, fileName: String) -> URL? {
    let destination = destinationURL(fileName: fileName)

    do {
      try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: destination, options: .atomic)
      return destination
    } catch {
      return nil
    }
  }

  private func destinationURL(fileName: String) -> URL {
    let safeName = fileName.isEmpty ? "attachment" : fileName
    return rootDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent(safeName)
  }
}
