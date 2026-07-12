import Foundation
import Testing
@testable import EaselChat

@Suite("TweakAgentProgressTimeout")
struct TweakAgentProgressTimeoutTests {
  @Test("Times out only after the inactivity interval")
  func timesOutAfterInactivity() {
    let start = ContinuousClock.now
    var timeout = TweakAgentProgressTimeout(
      interval: .seconds(300),
      initialActivity: 1,
      now: start
    )

    #expect(!timeout.hasTimedOut(activity: 1, now: start.advanced(by: .seconds(299))))
    #expect(timeout.hasTimedOut(activity: 1, now: start.advanced(by: .seconds(300))))
  }

  @Test("Progress resets the inactivity interval")
  func progressResetsTimeout() {
    let start = ContinuousClock.now
    var timeout = TweakAgentProgressTimeout(
      interval: .seconds(300),
      initialActivity: 1,
      now: start
    )

    #expect(!timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(290))))
    #expect(!timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(589))))
    #expect(timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(590))))
  }
}
