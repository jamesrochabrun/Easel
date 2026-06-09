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
  func scriptFastForwardsMotionForThumbnails() {
    let script = SlideDeckFirstSlidePreparationScript.script

    #expect(script.contains("const fastForwardMotion = true"))
    #expect(script.contains("__easel-slide-preview-fast-motion"))
    #expect(script.contains("animation-duration: 1ms !important"))
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
