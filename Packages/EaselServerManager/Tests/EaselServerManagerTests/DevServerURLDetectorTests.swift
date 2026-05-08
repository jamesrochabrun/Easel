//
//  DevServerURLDetectorTests.swift
//  EaselServerManagerTests
//

import Foundation
import Testing
@testable import EaselServerManager

struct DevServerURLDetectorTests {

  @Test
  func detectsAstroDevOutput() {
    let output = "  Local   http://localhost:4321/"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:4321/")
  }

  @Test
  func detectsViteDevOutput() {
    let output = "  > Local: http://localhost:5173/"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:5173/")
  }

  @Test
  func detectsNextJSDevOutput() {
    let output = "  - Local: http://localhost:3000"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:3000")
  }

  @Test
  func detectsURLWithPath() {
    let output = "Server running at http://localhost:4360/AgentHubPage"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:4360/AgentHubPage")
  }

  @Test
  func stripsANSIEscapeCodes() {
    let output = "\u{1B}[36m  Local  \u{1B}[39m http://localhost:4321/"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:4321/")
  }

  @Test
  func detects127001() {
    let output = "Listening on http://127.0.0.1:8080"
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://127.0.0.1:8080")
  }

  @Test
  func returnsNilForNoURL() {
    let output = "Starting compilation..."
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url == nil)
  }

  @Test
  func returnsNilForEmptyString() {
    let url = DevServerURLDetector.extractURL(from: "")
    #expect(url == nil)
  }

  @Test
  func trimsTrailingPunctuation() {
    let output = "Visit http://localhost:3000."
    let url = DevServerURLDetector.extractURL(from: output)
    #expect(url?.absoluteString == "http://localhost:3000")
  }
}
