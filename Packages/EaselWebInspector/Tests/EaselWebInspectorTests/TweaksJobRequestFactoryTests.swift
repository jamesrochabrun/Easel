//
//  TweaksJobRequestFactoryTests.swift
//  EaselWebInspectorTests
//

import Canvas
import EaselKit
import Foundation
import Testing
@testable import EaselWebInspector

struct TweaksJobRequestFactoryTests {

  private let projectPath = "/tmp/factory-tests/project"

  @Test
  func devServerRootResolvesToIndexHTML() throws {
    let request = try #require(TweaksJobRequestFactory.makeRequest(
      previewURL: URL(string: "http://localhost:5173/")!,
      projectPath: projectPath,
      instruction: .ideas
    ))

    #expect(request.kind == .tweaks)
    #expect(request.targetFileRelativePath == "index.html")
    #expect(request.displayFileName == "index.html")
    #expect(request.summary == "Ideas")
    #expect(request.prompt == TweaksPromptBuilder.ideasPrompt(fileName: "index.html"))
  }

  @Test
  func devServerNestedPathResolvesRelativePath() throws {
    let request = try #require(TweaksJobRequestFactory.makeRequest(
      previewURL: URL(string: "http://localhost:5173/pages/about.html")!,
      projectPath: projectPath,
      instruction: .custom("make it warmer")
    ))

    #expect(request.targetFileRelativePath == "pages/about.html")
    #expect(request.displayFileName == "about.html")
    #expect(request.summary == "make it warmer")
    #expect(request.prompt == TweaksPromptBuilder.customPrompt(
      fileName: "pages/about.html",
      instruction: "make it warmer"
    ))
  }

  @Test
  func fileURLInsideProjectResolves() throws {
    let request = try #require(TweaksJobRequestFactory.makeRequest(
      previewURL: URL(fileURLWithPath: "\(projectPath)/designs/hero.html"),
      projectPath: projectPath,
      instruction: .ideas
    ))

    #expect(request.targetFileRelativePath == "designs/hero.html")
    #expect(request.projectPath == projectPath)
  }

  @Test
  func fileURLOutsideProjectIsRejected() {
    let request = TweaksJobRequestFactory.makeRequest(
      previewURL: URL(fileURLWithPath: "/tmp/elsewhere/hero.html"),
      projectPath: projectPath,
      instruction: .ideas
    )
    #expect(request == nil)
  }

  @Test
  func unsupportedSchemeIsRejected() {
    let request = TweaksJobRequestFactory.makeRequest(
      previewURL: URL(string: "about:blank")!,
      projectPath: projectPath,
      instruction: .ideas
    )
    #expect(request == nil)
  }
}
