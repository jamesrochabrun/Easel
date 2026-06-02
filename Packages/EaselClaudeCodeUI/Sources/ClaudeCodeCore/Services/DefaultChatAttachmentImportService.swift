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
    temporaryDirectory: URL = FileManager.default.temporaryDirectory
  ) {
    self.fileManager = fileManager
    self.temporaryDirectory = temporaryDirectory
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
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
       let url = await loadFileURL(from: provider) {
      return attachments(from: url)
    }

    guard let imagePayload = await loadImageData(from: provider),
          let temporaryURL = writeTemporaryImage(payload: imagePayload, provider: provider) else {
      return []
    }

    return [FileAttachment(url: temporaryURL, isTemporary: true)]
  }

  private func attachments(from url: URL) -> [FileAttachment] {
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return []
    }

    if isDirectory.boolValue {
      return collectFiles(from: url).map { FileAttachment(url: $0) }
    }

    return [FileAttachment(url: url, isTemporary: isTemporaryFile(url))]
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

  private func writeTemporaryImage(payload: ImageDropPayload, provider: NSItemProvider) -> URL? {
    let fileName = temporaryImageFileName(type: payload.type, provider: provider)
    let url = temporaryDirectory.appendingPathComponent(fileName)

    do {
      try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
      try payload.data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
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
