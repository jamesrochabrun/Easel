//
//  LocalhostURLExtractorTests.swift
//  EaselChatTests
//

import Testing
@testable import EaselChat

struct LocalhostURLExtractorTests {
  let extractor = LocalhostURLExtractor()

  // MARK: - Happy Path

  @Test
  func extractsViteDevServerURL() {
    let text = """
      VITE v5.0.0  ready in 300 ms
      ➜  Local:   http://localhost:5173/
      ➜  Network: use --host to expose
      """
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:5173/")
  }

  @Test
  func extractsNextJSURL() {
    let text = "ready - started server on 0.0.0.0:3000, url: http://localhost:3000"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:3000")
  }

  @Test
  func extracts127001URL() {
    let text = "Server running at http://127.0.0.1:8080/app"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://127.0.0.1:8080/app")
  }

  @Test
  func extractsLatestURLWhenMultiple() {
    let text = """
      Old server: http://localhost:3000
      New server: http://localhost:5173
      """
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:5173")
  }

  @Test
  func handlesHTTPS() {
    let text = "Server: https://localhost:3000"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "https://localhost:3000")
  }

  @Test
  func handlesURLWithPath() {
    let text = "Available at http://localhost:4200/dashboard/home"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:4200/dashboard/home")
  }

  @Test
  func handlesCreateReactAppOutput() {
    let text = """
      Compiled successfully!

      You can now view my-app in the browser.

        Local:            http://localhost:3000
        On Your Network:  http://192.168.1.5:3000
      """
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:3000")
  }

  // MARK: - Edge Cases

  @Test
  func returnsNilForNoURL() {
    let text = "Build completed successfully."
    #expect(extractor.extractPreviewURL(from: text) == nil)
  }

  @Test
  func returnsNilForEmptyString() {
    #expect(extractor.extractPreviewURL(from: "") == nil)
  }

  @Test
  func returnsNilForNonLocalhostURL() {
    let text = "Deployed to https://example.com"
    #expect(extractor.extractPreviewURL(from: text) == nil)
  }

  @Test
  func returnsNilForLocalhostWithoutPort() {
    let text = "Visit http://localhost for more info"
    #expect(extractor.extractPreviewURL(from: text) == nil)
  }

  @Test
  func handlesTrailingPeriod() {
    let text = "Server started at http://localhost:3000."
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:3000")
  }

  @Test
  func handlesTrailingBacktick() {
    let text = "Preview: `http://127.0.0.1:4173/`"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://127.0.0.1:4173/")
  }

  @Test
  func stripsEncodedTrailingBacktick() {
    let text = "Preview: http://127.0.0.1:4173/%60"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://127.0.0.1:4173/")
  }

  @Test
  func handlesURLInParentheses() {
    let text = "Server running (http://localhost:3000)"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url != nil)
  }

  @Test
  func handlesHighPortNumber() {
    let text = "http://localhost:49152"
    let url = extractor.extractPreviewURL(from: text)
    #expect(url?.absoluteString == "http://localhost:49152")
  }
}
