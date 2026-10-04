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

  func testAttachmentsFromProvidersWritesDroppedPNGDataToDurableStore() async throws {
    let storeRoot = temporaryRoot.appendingPathComponent("Store")
    let pngData = try XCTUnwrap(Data(base64Encoded: Self.onePixelPNGBase64))
    let provider = NSItemProvider()
    provider.suggestedName = "Dragged Screenshot"
    provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
      completion(pngData, nil)
      return nil
    }

    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryRoot,
      attachmentStore: ChatAttachmentStore(rootDirectory: storeRoot)
    )
    let attachments = await service.attachments(from: [provider])
    let attachment = try XCTUnwrap(attachments.first)

    XCTAssertEqual(attachments.count, 1)
    XCTAssertEqual(attachment.type, .image)
    XCTAssertTrue(attachment.isTemporary)
    XCTAssertEqual(attachment.url.deletingPathExtension().lastPathComponent, "Dragged Screenshot")
    XCTAssertEqual(attachment.url.pathExtension, "png")
    XCTAssertTrue(attachment.url.path.hasPrefix(storeRoot.path), "dropped image bytes must land in the durable store")
    XCTAssertEqual(try Data(contentsOf: attachment.url), pngData)
  }

  func testTemporaryScreenshotFileIsCopiedAndSurvivesSourceDeletion() async throws {
    // Mimic the screencaptureui layout: the service's temp-dir heuristic
    // flags anything under a TemporaryItems path as a screenshot.
    let screenshotDirectory = temporaryRoot
      .appendingPathComponent("TemporaryItems")
      .appendingPathComponent("NSIRD_screencaptureui_test")
    try FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)
    let screenshotURL = screenshotDirectory.appendingPathComponent("Screenshot.png")
    let pngData = try XCTUnwrap(Data(base64Encoded: Self.onePixelPNGBase64))
    try pngData.write(to: screenshotURL)

    let storeRoot = temporaryRoot.appendingPathComponent("Store")
    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryRoot,
      attachmentStore: ChatAttachmentStore(rootDirectory: storeRoot)
    )

    let attachments = await service.attachments(from: [screenshotURL])
    let attachment = try XCTUnwrap(attachments.first)

    XCTAssertTrue(attachment.isTemporary)
    XCTAssertTrue(attachment.url.path.hasPrefix(storeRoot.path), "screenshot must be copied out of the purgeable location")
    XCTAssertEqual(attachment.url.lastPathComponent, "Screenshot.png")

    // The system reaps the original moments after the drag — the copy keeps working.
    try FileManager.default.removeItem(at: screenshotURL)
    XCTAssertEqual(try Data(contentsOf: attachment.url), pngData)
  }

  func testStableFinderFilesAreReferencedInPlaceNotCopied() async throws {
    let projectRoot = temporaryRoot.appendingPathComponent("StableProject")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    let fileURL = projectRoot.appendingPathComponent("notes.md")
    try "# Notes".write(to: fileURL, atomically: true, encoding: .utf8)

    let storeRoot = temporaryRoot.appendingPathComponent("Store")
    // A service whose temp heuristic does not match projectRoot.
    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryRoot.appendingPathComponent("Elsewhere"),
      attachmentStore: ChatAttachmentStore(rootDirectory: storeRoot)
    )

    let attachments = await service.attachments(from: [fileURL])
    let attachment = try XCTUnwrap(attachments.first)

    XCTAssertFalse(attachment.isTemporary)
    XCTAssertEqual(attachment.url, fileURL)
  }

  func testFilePromiseStyleProviderFallsBackToFileRepresentation() async throws {
    // A provider that vends only a file representation (how file promises
    // surface through NSItemProvider) — no fileURL item, no data route
    // registered for a non-image type.
    let promisedFile = temporaryRoot.appendingPathComponent("promised.pdf")
    try Data([0x25, 0x50, 0x44, 0x46]).write(to: promisedFile)

    let provider = NSItemProvider()
    provider.registerFileRepresentation(
      forTypeIdentifier: UTType.pdf.identifier,
      fileOptions: [],
      visibility: .all
    ) { completion in
      completion(promisedFile, false, nil)
      return nil
    }

    let storeRoot = temporaryRoot.appendingPathComponent("Store")
    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryRoot,
      attachmentStore: ChatAttachmentStore(rootDirectory: storeRoot)
    )

    let attachments = await service.attachments(from: [provider])
    let attachment = try XCTUnwrap(attachments.first)

    XCTAssertTrue(attachment.url.path.hasPrefix(storeRoot.path), "promised files must be copied out before the vended URL is invalidated")
    XCTAssertEqual(attachment.url.lastPathComponent, "promised.pdf")
    XCTAssertTrue(attachment.isTemporary)
  }

  func testPlainTextProviderProducesNoAttachments() async {
    // The file-representation fallback must not materialize dragged text
    // into a file.
    let provider = NSItemProvider(item: "not a file" as NSString, typeIdentifier: UTType.utf8PlainText.identifier)
    let service = DefaultChatAttachmentImportService(
      temporaryDirectory: temporaryRoot,
      attachmentStore: ChatAttachmentStore(rootDirectory: temporaryRoot.appendingPathComponent("Store"))
    )

    let attachments = await service.attachments(from: [provider])

    XCTAssertTrue(attachments.isEmpty)
  }

  private static let onePixelPNGBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
}
