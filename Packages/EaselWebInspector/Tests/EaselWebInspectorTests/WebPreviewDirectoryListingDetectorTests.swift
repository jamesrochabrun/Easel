//
//  WebPreviewDirectoryListingDetectorTests.swift
//  EaselWebInspectorTests
//

import Testing
@testable import EaselWebInspector

@Suite("WebPreviewDirectoryListingDetector")
struct WebPreviewDirectoryListingDetectorTests {
  @Test("Detects the Python http.server autoindex title")
  func detectsDirectoryListing() {
    #expect(WebPreviewDirectoryListingDetector.isDirectoryListing(title: "Directory listing for /"))
    #expect(WebPreviewDirectoryListingDetector.isDirectoryListing(
      title: "Directory listing for /?easelReload=C5AEC979-2153-4716-8A5E-BD7EA1AF716B"
    ))
    #expect(WebPreviewDirectoryListingDetector.isDirectoryListing(title: "  Directory listing for /resources/"))
  }

  @Test("Treats a real page title as not a directory listing")
  func ignoresRealPages() {
    #expect(!WebPreviewDirectoryListingDetector.isDirectoryListing(title: "Star Wars | Movie Landing Page"))
    #expect(!WebPreviewDirectoryListingDetector.isDirectoryListing(title: ""))
    #expect(!WebPreviewDirectoryListingDetector.isDirectoryListing(title: nil))
  }
}
