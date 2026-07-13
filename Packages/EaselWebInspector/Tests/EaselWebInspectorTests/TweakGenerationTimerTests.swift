import Foundation
import Testing
@testable import EaselWebInspector

@Suite("TweakGenerationTimer")
struct TweakGenerationTimerTests {
  @Test("Keeps the generation start time until work stops")
  func lifecycle() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    var timer = TweakGenerationTimer()

    timer.start(at: start)
    #expect(timer.startedAt == start)

    timer.stop()
    #expect(timer.startedAt == nil)
  }
}
