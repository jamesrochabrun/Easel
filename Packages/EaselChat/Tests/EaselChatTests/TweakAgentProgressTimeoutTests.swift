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

    let beforeInterval = timeout.hasTimedOut(activity: 1, now: start.advanced(by: .seconds(299)))
    let atInterval = timeout.hasTimedOut(activity: 1, now: start.advanced(by: .seconds(300)))

    #expect(!beforeInterval)
    #expect(atInterval)
  }

  @Test("Progress resets the inactivity interval")
  func progressResetsTimeout() {
    let start = ContinuousClock.now
    var timeout = TweakAgentProgressTimeout(
      interval: .seconds(300),
      initialActivity: 1,
      now: start
    )

    let afterProgress = timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(290)))
    let beforeResetInterval = timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(589)))
    let atResetInterval = timeout.hasTimedOut(activity: 2, now: start.advanced(by: .seconds(590)))

    #expect(!afterProgress)
    #expect(!beforeResetInterval)
    #expect(atResetInterval)
  }
}
