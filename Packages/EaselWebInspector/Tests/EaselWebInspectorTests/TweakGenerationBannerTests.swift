import Foundation
import Testing
@testable import EaselWebInspector

@Suite("TweakGenerationBanner")
struct TweakGenerationBannerTests {
  @Test("Explains that generation can take a few minutes")
  func messageSetsTimingExpectation() {
    #expect(TweakGenerationBanner.message == "Tweaks are being generated. This can take a few minutes.")
  }

  @Test("Formats elapsed generation time")
  func formatsElapsedTime() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(TweakGenerationBanner.elapsedTime(from: start, to: start.addingTimeInterval(65)) == "1:05")
    #expect(TweakGenerationBanner.elapsedTime(from: start, to: start.addingTimeInterval(3_661)) == "1:01:01")
    #expect(TweakGenerationBanner.elapsedTime(from: start, to: start.addingTimeInterval(-1)) == "0:00")
  }
}
