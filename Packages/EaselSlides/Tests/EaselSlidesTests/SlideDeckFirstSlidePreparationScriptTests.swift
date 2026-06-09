//
//  SlideDeckFirstSlidePreparationScriptTests.swift
//  EaselSlidesTests
//

import EaselSlides
import Testing

struct SlideDeckFirstSlidePreparationScriptTests {
  @Test
  func scriptInstallsRuntimeAndSelectsFirstSlide() {
    let script = SlideDeckFirstSlidePreparationScript.script

    #expect(script.contains("__easelSlideDeckRuntime"))
    #expect(script.contains(".select(0)"))
  }

  @Test
  func scriptEnforcesFullBleedDeckStage() {
    let script = SlideDeckFirstSlidePreparationScript.script

    #expect(script.contains("[data-easel-deck]"))
    #expect(script.contains("width: 100vw !important"))
    #expect(script.contains("height: 100vh !important"))
    #expect(script.contains("padding: 0 !important"))
    #expect(script.contains("border-radius: 0 !important"))
    #expect(script.contains("box-shadow: none !important"))
    #expect(script.contains("overflow: hidden !important"))
    #expect(script.contains("clip-path: inset(0) !important"))
    #expect(script.contains("contain: paint !important"))
  }
}
