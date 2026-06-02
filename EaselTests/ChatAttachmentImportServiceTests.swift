//
//  ChatAttachmentImportServiceTests.swift
//  EaselTests
//

import ClaudeCodeCore
import Foundation
import Testing
import UniformTypeIdentifiers

struct ChatAttachmentImportServiceTests {

  @Test
  func droppedImageDataCreatesTemporaryAttachment() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselChatAttachmentImportServiceTests")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
    let provider = NSItemProvider()
    provider.suggestedName = "Dropped Image"
    provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
      completion(pngData, nil)
      return nil
    }

    let service = DefaultChatAttachmentImportService(temporaryDirectory: temporaryDirectory)
    let attachments = await service.attachments(from: [provider])
    let attachment = try #require(attachments.first)

    #expect(attachments.count == 1)
    #expect(attachment.type == .image)
    #expect(attachment.isTemporary)
    #expect(attachment.url.pathExtension == "png")
    #expect(FileManager.default.fileExists(atPath: attachment.url.path))
  }

  @Test
  func droppedFinderFileURLCreatesFileAttachment() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let sourceDirectory = temporaryDirectory.appendingPathComponent("Source", isDirectory: true)
    let fileURL = sourceDirectory.appendingPathComponent("mockup.png")
    try writeFile(fileURL, contents: "image placeholder")

    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
      completion(fileURL.dataRepresentation, nil)
      return nil
    }

    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryDirectory.appendingPathComponent("Drops", isDirectory: true)
    )
    let attachments = await service.attachments(from: [provider])

    #expect(attachments.count == 1)
    #expect(attachments.first?.url.path == fileURL.path)
    #expect(attachments.first?.type == .image)
    #expect(attachments.first?.isTemporary == false)
  }

  @Test
  func importedFolderExpandsVisibleRegularFiles() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let folderURL = temporaryDirectory.appendingPathComponent("Project", isDirectory: true)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    try writeFile(folderURL.appendingPathComponent("visible.txt"), contents: "visible")
    try writeFile(folderURL.appendingPathComponent(".DS_Store"), contents: "system")
    try writeFile(folderURL.appendingPathComponent(".hidden.txt"), contents: "hidden")
    try writeFile(folderURL.appendingPathComponent("Nested/App.swift"), contents: "import SwiftUI")

    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryDirectory.appendingPathComponent("Drops", isDirectory: true)
    )
    let attachments = await service.attachments(from: [folderURL])

    #expect(attachments.map(\.fileName).sorted() == ["App.swift", "visible.txt"])
    #expect(attachments.allSatisfy { !$0.isTemporary })
  }

  @Test
  func unsupportedProviderProducesNoAttachments() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let provider = NSItemProvider(item: "not a file" as NSString, typeIdentifier: UTType.utf8PlainText.identifier)
    let service = DefaultChatAttachmentImportService(temporaryDirectory: temporaryDirectory)

    let attachments = await service.attachments(from: [provider])

    #expect(attachments.isEmpty)
  }

  @Test
  func acceptedContentTypesCoverFinderFilesAndImages() {
    let types = DefaultChatAttachmentImportService.acceptedContentTypes

    #expect(types.contains(.fileURL))
    #expect(types.contains(.image))
    #expect(types.contains(.png))
    #expect(types.contains(.jpeg))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("EaselChatAttachmentImportServiceTests")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func writeFile(_ url: URL, contents: String) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  private static let onePixelPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
