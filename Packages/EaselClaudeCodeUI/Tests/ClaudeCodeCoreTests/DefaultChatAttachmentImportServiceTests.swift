import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import ClaudeCodeCore

final class DefaultChatAttachmentImportServiceTests: XCTestCase {
  private var temporaryRoot: URL!

  override func setUpWithError() throws {
    temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("DefaultChatAttachmentImportServiceTests")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryRoot {
      try? FileManager.default.removeItem(at: temporaryRoot)
    }
    temporaryRoot = nil
  }

  func testAttachmentsFromURLsExpandsFoldersAndSkipsHiddenSystemFiles() async throws {
    let folderURL = temporaryRoot.appendingPathComponent("DroppedFolder")
    let nestedURL = folderURL.appendingPathComponent("Nested")
    try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)

    let visibleTextURL = folderURL.appendingPathComponent("notes.txt")
    let visibleSwiftURL = nestedURL.appendingPathComponent("View.swift")
    let hiddenURL = folderURL.appendingPathComponent(".hidden.txt")
    let systemURL = folderURL.appendingPathComponent(".DS_Store")

    try "notes".write(to: visibleTextURL, atomically: true, encoding: .utf8)
    try "struct View {}".write(to: visibleSwiftURL, atomically: true, encoding: .utf8)
    try "hidden".write(to: hiddenURL, atomically: true, encoding: .utf8)
    try "system".write(to: systemURL, atomically: true, encoding: .utf8)

    let service = DefaultChatAttachmentImportService(temporaryDirectory: temporaryRoot)
    let attachments = await service.attachments(from: [folderURL])
    let paths = attachments.map { $0.url.resolvingSymlinksInPath().path }.sorted()
    let expectedPaths = [visibleTextURL, visibleSwiftURL]
      .map { $0.resolvingSymlinksInPath().path }
      .sorted()

    XCTAssertEqual(paths, expectedPaths)
    XCTAssertEqual(attachments.map(\.isTemporary), [false, false])
  }

  func testAttachmentsFromProvidersImportsFinderFileURL() async throws {
    let serviceTemporaryDirectory = temporaryRoot.appendingPathComponent("ServiceTemporary")
    try FileManager.default.createDirectory(at: serviceTemporaryDirectory, withIntermediateDirectories: true)

    let fileURL = temporaryRoot.appendingPathComponent("dropped.md")
    try "# Dropped".write(to: fileURL, atomically: true, encoding: .utf8)

    let provider = NSItemProvider(item: fileURL as NSURL, typeIdentifier: UTType.fileURL.identifier)
    let service = DefaultChatAttachmentImportService(temporaryDirectory: serviceTemporaryDirectory)

    let attachments = await service.attachments(from: [provider])

    XCTAssertEqual(attachments.count, 1)
    XCTAssertEqual(attachments.first?.url, fileURL)
    XCTAssertEqual(attachments.first?.type, .markdown)
    XCTAssertEqual(attachments.first?.isTemporary, false)
  }

  func testAttachmentsFromProvidersWritesDroppedPNGDataToTemporaryFile() async throws {
    let pngData = try XCTUnwrap(Data(base64Encoded: Self.onePixelPNGBase64))
    let provider = NSItemProvider()
    provider.suggestedName = "Dragged Screenshot"
    provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
      completion(pngData, nil)
      return nil
    }

    let service = DefaultChatAttachmentImportService(temporaryDirectory: temporaryRoot)
    let attachments = await service.attachments(from: [provider])
    let attachment = try XCTUnwrap(attachments.first)

    XCTAssertEqual(attachments.count, 1)
    XCTAssertEqual(attachment.type, .image)
    XCTAssertTrue(attachment.isTemporary)
    XCTAssertEqual(attachment.url.deletingPathExtension().lastPathComponent, "Dragged Screenshot")
    XCTAssertEqual(attachment.url.pathExtension, "png")
    XCTAssertEqual(try Data(contentsOf: attachment.url), pngData)
  }

  private static let onePixelPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
