import Canvas
import Testing
@testable import EaselWebInspector

@Suite("TweakPanelStatusRouting")
struct TweakPanelStatusRoutingTests {
  @Test("Canvas does not duplicate host agent status", arguments: [
    TweaksAgentState.idle,
    .working,
    .failed("Failure"),
    .conflict,
  ])
  func canvasAgentStatusIsIdle(state: TweaksAgentState) {
    #expect(TweakPanelStatusRouting.canvasAgentState(for: state) == .idle)
  }

  @Test("Canvas retains only the defaults saving state")
  func canvasDefaultsStatus() {
    #expect(TweakPanelStatusRouting.canvasDefaultsState(for: .idle) == .idle)
    #expect(TweakPanelStatusRouting.canvasDefaultsState(for: .saving) == .saving)
    #expect(TweakPanelStatusRouting.canvasDefaultsState(for: .failed("Failure")) == .idle)
  }

  @Test("Host status appears only for visible status content")
  func hostStatusVisibility() {
    #expect(!TweakPanelStatusRouting.showsHostStatus(agentState: .idle, defaultsState: .idle))
    #expect(!TweakPanelStatusRouting.showsHostStatus(agentState: .idle, defaultsState: .saving))
    #expect(TweakPanelStatusRouting.showsHostStatus(agentState: .working, defaultsState: .idle))
    #expect(TweakPanelStatusRouting.showsHostStatus(agentState: .failed("Failure"), defaultsState: .idle))
    #expect(TweakPanelStatusRouting.showsHostStatus(agentState: .idle, defaultsState: .failed("Failure")))
  }
}
