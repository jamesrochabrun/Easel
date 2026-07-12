import Canvas

enum TweakPanelStatusRouting {
  static func canvasAgentState(for state: TweaksAgentState) -> TweaksAgentState {
    .idle
  }

  static func canvasDefaultsState(
    for state: TweaksDefaultsSaveState
  ) -> TweaksDefaultsSaveState {
    state == .saving ? .saving : .idle
  }

  static func showsHostStatus(
    agentState: TweaksAgentState,
    defaultsState: TweaksDefaultsSaveState
  ) -> Bool {
    if agentState != .idle {
      return true
    }
    if case .failed = defaultsState {
      return true
    }
    return false
  }
}
