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
}
