//
//  ProjectResourceCodeLanguageMapperTests.swift
//  EaselChatTests
//

import HighlightSwift
import Testing
@testable import EaselChat

struct ProjectResourceCodeLanguageMapperTests {
  @Test
  func mapsKnownFileExtensionsToHighlightLanguages() {
    let mapper = ProjectResourceCodeLanguageMapper()

    #expect(mapper.highlightMode(forFileName: "index.html") == .languageIgnoreIllegal(.html))
    #expect(mapper.highlightMode(forFileName: "deck-stage.js") == .languageIgnoreIllegal(.javaScript))
    #expect(mapper.highlightMode(forFileName: "CanvasView.swift") == .languageIgnoreIllegal(.swift))
    #expect(mapper.highlightMode(forFileName: "styles/site.css") == .languageIgnoreIllegal(.css))
  }

  @Test
  func normalizesAliasesAndSpecialFileNames() {
    let mapper = ProjectResourceCodeLanguageMapper()

    #expect(mapper.highlightMode(forFileName: "App.tsx") == .languageIgnoreIllegal(.typeScript))
    #expect(mapper.highlightMode(forFileName: "Dockerfile") == .languageIgnoreIllegal(.dockerfile))
    #expect(mapper.highlightMode(forFileName: ".zshrc") == .languageIgnoreIllegal(.shell))
    #expect(mapper.highlightMode(forFileName: "Info.plist") == .languageIgnoreIllegal(.html))
  }

  @Test
  func returnsReadableDisplayNamesForAliases() {
    let mapper = ProjectResourceCodeLanguageMapper()

    #expect(mapper.displayName(forFileName: "index.htm") == "html")
    #expect(mapper.displayName(forFileName: "App.tsx") == "typescript")
    #expect(mapper.displayName(forFileName: "script.py") == "python")
    #expect(mapper.displayName(forFileName: "notes.txt") == "plaintext")
    #expect(mapper.displayName(forFileName: "README") == nil)
  }
}
