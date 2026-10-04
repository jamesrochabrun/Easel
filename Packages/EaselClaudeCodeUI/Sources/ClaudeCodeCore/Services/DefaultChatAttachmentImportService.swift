//
//  DefaultChatAttachmentImportService.swift
//  ClaudeCodeUI
//

import Foundation
import UniformTypeIdentifiers

public final class DefaultChatAttachmentImportService: ChatAttachmentImportService, @unchecked Sendable {
  public static let acceptedContentTypes: [UTType] = [
    .fileURL,
    .folder,
    .image,
    .png,
    .jpeg,
    .tiff,
    .heic,
  ]

  public var acceptedContentTypes: [UTType] {
    Self.acceptedContentTypes
  }

  private let fileManager: FileManager
  private let temporaryDirectory: URL
  private let attachmentStore: ChatAttachmentStore
  private let systemFileNames: Set<String> = [
    ".DS_Store",
    ".localized",
    "Thumbs.db",
    "desktop.ini",
    ".git",
    ".svn"
  ]

  public init(
    fileManager: FileManager = .default,
    temporaryDirectory: URL = FileManager.default.temporaryDirectory,
    attachmentStore: ChatAttachmentStore? = nil
  ) {
    self.fileManager = fileManager
    self.temporaryDirectory = temporaryDirectory
    self.attachmentStore = attachmentStore ?? ChatAttachmentStore(fileManager: fileManager)
  }

  public func attachments(from urls: [URL]) async -> [FileAttachment] {
    urls.flatMap { attachments(from: $0) }
  }

  public func attachments(from providers: [NSItemProvider]) async -> [FileAttachment] {
    var importedAttachments: [FileAttachment] = []

    for provider in providers {
      importedAttachments.append(contentsOf: await attachments(from: provider))
    }

    return importedAttachments
  }

  private func attachments(from provider: NSItemProvider) async -> [FileAttachment] {
    // A concrete file URL first (files and folders). This can resolve to a
    // path that no longer exists — e.g. a screenshot HUD thumbnail whose
    // backing file screencaptureui already reaped — so an empty result
    // falls through to the data and file-representation routes instead of
    // silently dropping the drag.
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
       let url = await loadFileURL(from: provider) {
      let resolved = attachments(from: url)
      if !resolved.isEmpty {
        return resolved
      }
    }

    // Raw image bytes (screenshots and browser drags that carry no usable
    // URL). Written straight into the durable store.
    if let imagePayload = await loadImageData(from: provider),
       let storedURL = writeDroppedImage(payload: imagePayload, provider: provider) {
      return [FileAttachment(url: storedURL, isTemporary: true)]
    }

    // Last resort: ask the provider to materialize a file representation.
    // This is the route that services file promises — the vended URL is
    // only valid inside the callback, so it is copied out immediately.
    if let copiedURL = await loadFileRepresentationCopy(from: provider) {
      return [FileAttachment(url: copiedURL, isTemporary: true)]
    }

    return []
  }

  private func attachments(from url: URL) -> [FileAttachment] {
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return []
    }

    if isDirectory.boolValue {
      return collectFiles(from: url).map { FileAttachment(url: $0) }
    }

    // Files in purgeable locations (screenshots, clipboard temp files) are
    // copied into the app-owned store right now — the original can vanish
    // seconds later, long before the message is sent or the CLI reads it.
    if isTemporaryFile(url) {
      let stableURL = attachmentStore.importCopy(of: url) ?? url
      return [FileAttachment(url: stableURL, isTemporary: true)]
    }

    return [FileAttachment(url: url, isTemporary: false)]
  }

  private func collectFiles(from folderURL: URL) -> [URL] {
    guard let enumerator = fileManager.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
      return []
    }

    var urls: [URL] = []

    for case let fileURL as URL in enumerator {
      do {
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
        guard values.isRegularFile == true, values.isHidden != true else {
          continue
        }

        let fileName = fileURL.lastPathComponent
        guard !isSystemFile(fileName) else {
          continue
        }

        urls.append(fileURL)
      } catch {
        continue
      }
    }

    return urls.sorted { $0.path < $1.path }
  }

  private func isSystemFile(_ fileName: String) -> Bool {
    systemFileNames.contains(fileName) || fileName.hasPrefix("~$")
  }

  private func isTemporaryFile(_ url: URL) -> Bool {
    let path = url.standardizedFileURL.path
    return path.hasPrefix(temporaryDirectory.standardizedFileURL.path)
      || path.contains("TemporaryItems")
      || path.localizedCaseInsensitiveContains("screencaptureui")
  }

  private func loadFileURL(from provider: NSItemProvider) async -> URL? {
    guard let item = await loadItem(from: provider, typeIdentifier: UTType.fileURL.identifier) else {
      return nil
    }

    if let url = item as? URL {
      return url
    }

    if let url = item as? NSURL {
      return url as URL
    }

    if let data = item as? Data {
      return URL(dataRepresentation: data, relativeTo: nil)
        ?? String(data: data, encoding: .utf8).flatMap(url(from:))
    }

    if let string = item as? String {
      return url(from: string)
    }

    return nil
  }

  private func url(from string: String) -> URL? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

    if let url = URL(string: trimmed), url.isFileURL {
      return url
    }

    guard !trimmed.isEmpty else {
      return nil
    }

    return URL(fileURLWithPath: trimmed)
  }

  private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
        continuation.resume(returning: item)
      }
    }
  }

  private func loadImageData(from provider: NSItemProvider) async -> ImageDropPayload? {
    for type in imageTypes(from: provider) {
      if let data = await loadData(from: provider, type: type) {
        return ImageDropPayload(data: data, type: type)
      }
    }

    return nil
  }

  private func imageTypes(from provider: NSItemProvider) -> [UTType] {
    let registeredTypes = provider.registeredTypeIdentifiers.compactMap(UTType.init)
    let concreteImageTypes = registeredTypes.filter {
      $0.conforms(to: .image) && $0.identifier != UTType.image.identifier
    }

    var orderedTypes: [UTType] = [.png, .jpeg, .tiff, .heic]
    orderedTypes.append(contentsOf: concreteImageTypes)

    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      orderedTypes.append(.image)
    }

    return orderedTypes.reduce(into: []) { result, type in
      guard !result.contains(where: { $0.identifier == type.identifier }) else {
        return
      }
      result.append(type)
    }
  }

  private func loadData(from provider: NSItemProvider, type: UTType) async -> Data? {
    await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(for: type) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }

  private func writeDroppedImage(payload: ImageDropPayload, provider: NSItemProvider) -> URL? {
    let fileName = temporaryImageFileName(type: payload.type, provider: provider)
    return attachmentStore.write(data: payload.data, fileName: fileName)
  }

  /// Materializes the provider's file representation (servicing a file
  /// promise if that's what the drag carries) and copies it into the
  /// durable store before the system-vended URL is invalidated.
  private func loadFileRepresentationCopy(from provider: NSItemProvider) async -> URL? {
    // Only representations that are really file-shaped: a dragged string or
    // link must not be materialized into a file by this fallback.
    let candidateTypes = provider.registeredTypeIdentifiers.filter { identifier in
      guard identifier != UTType.fileURL.identifier,
            let type = UTType(identifier) else {
        return false
      }
      return !type.conforms(to: .text) && !type.conforms(to: .url)
    }

    for typeIdentifier in candidateTypes {
      let copied: URL? = await withCheckedContinuation { continuation in
        _ = provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [attachmentStore] url, _ in
          guard let url else {
            continuation.resume(returning: nil)
            return
          }
          // The URL is deleted when this handler returns — copy synchronously.
          continuation.resume(returning: attachmentStore.importCopy(of: url))
        }
      }

      if let copied {
        return copied
      }
    }

    return nil
  }

  private func temporaryImageFileName(type: UTType, provider: NSItemProvider) -> String {
    let baseName = sanitizedFileBaseName(provider.suggestedName) ?? "dropped_image_\(UUID().uuidString)"
    let pathExtension = type.preferredFilenameExtension ?? "png"

    if URL(fileURLWithPath: baseName).pathExtension.isEmpty {
      return "\(baseName).\(pathExtension)"
    }

    return baseName
  }

  private func sanitizedFileBaseName(_ name: String?) -> String? {
    guard let name else {
      return nil
    }

    let invalidCharacters = CharacterSet(charactersIn: "/:")
      .union(.newlines)
      .union(.controlCharacters)
    let components = name.components(separatedBy: invalidCharacters)
    let sanitized = components.joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)

    return sanitized.isEmpty ? nil : sanitized
  }
}

private struct ImageDropPayload {
  let data: Data
  let type: UTType
}
