import AgentHarness
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ClaudeCodeCore

final class APIImageContentConverterTests: XCTestCase {

  private var tempDir: URL!

  override func setUpWithError() throws {
    tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("image-converter-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDir)
  }

  private func writeTestPNG(width: Int, height: Int, name: String) throws -> URL {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!

    let url = tempDir.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return url
  }

  private func decodedImageSize(fromDataURL dataURL: String) throws -> CGSize {
    let base64 = try XCTUnwrap(dataURL.components(separatedBy: "base64,").last)
    let data = try XCTUnwrap(Data(base64Encoded: base64))
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return CGSize(width: image.width, height: image.height)
  }

  // MARK: - Marker parsing

  func testExtractsMarkerPathsInOrderAndPreservesText() {
    let prompt = """
    Build the hero section.
    Analyze this image: /tmp/a.png
    Some middle text.
    Analyze this image: /tmp/b with spaces.jpg
    """
    XCTAssertEqual(
      APIImageContentConverter.imagePaths(in: prompt),
      ["/tmp/a.png", "/tmp/b with spaces.jpg"]
    )

    let blocks = APIImageContentConverter.contentBlocks(for: prompt)
    guard case .text(let text)? = blocks.first else {
      return XCTFail("first block must be the unchanged prompt text")
    }
    XCTAssertEqual(text, prompt, "marker lines stay in the text for non-vision fallback")
  }

  func testNoMarkersYieldsSingleTextBlock() {
    let blocks = APIImageContentConverter.contentBlocks(for: "plain prompt, no images")
    XCTAssertEqual(blocks.count, 1)
  }

  func testMissingFileIsSkippedSilently() {
    let prompt = "Analyze this image: \(tempDir.appendingPathComponent("nope.png").path)"
    let blocks = APIImageContentConverter.contentBlocks(for: prompt)
    XCTAssertEqual(blocks.count, 1, "unreadable image adds no block")
  }

  func testNonImageFileIsSkipped() throws {
    let url = tempDir.appendingPathComponent("notimage.png")
    try "just text".write(to: url, atomically: true, encoding: .utf8)
    let blocks = APIImageContentConverter.contentBlocks(for: "Analyze this image: \(url.path)")
    XCTAssertEqual(blocks.count, 1)
  }

  // MARK: - Conversion

  func testLargeImageIsDownscaledJPEGDataURL() throws {
    let url = try writeTestPNG(width: 3_000, height: 2_000, name: "big.png")
    let blocks = APIImageContentConverter.contentBlocks(for: "Analyze this image: \(url.path)")

    XCTAssertEqual(blocks.count, 2)
    guard case .imageDataURL(let dataURL) = blocks[1] else {
      return XCTFail("expected image block")
    }
    XCTAssertTrue(dataURL.hasPrefix("data:image/jpeg;base64,"))

    let size = try decodedImageSize(fromDataURL: dataURL)
    XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(APIImageContentConverter.maxPixelSize))
    XCTAssertEqual(size.width / size.height, 1.5, accuracy: 0.05, "aspect ratio preserved")
  }

  func testSmallImageIsNotUpscaled() throws {
    let url = try writeTestPNG(width: 200, height: 100, name: "small.png")
    let blocks = APIImageContentConverter.contentBlocks(for: "Analyze this image: \(url.path)")
    guard case .imageDataURL(let dataURL)? = blocks.last, blocks.count == 2 else {
      return XCTFail("expected image block")
    }
    let size = try decodedImageSize(fromDataURL: dataURL)
    XCTAssertLessThanOrEqual(max(size.width, size.height), 200)
  }
}
