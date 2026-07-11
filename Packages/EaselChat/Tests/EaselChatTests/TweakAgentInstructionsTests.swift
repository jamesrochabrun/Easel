import Testing
@testable import EaselChat

@Suite("TweakAgentInstructions")
struct TweakAgentInstructionsTests {
  @Test func requiresCumulativeNonDuplicateIdeas() {
    let prompt = TweakAgentInstructions.systemPrompt

    #expect(prompt.contains("Treat existing tweak controls as cumulative project state"))
    #expect(prompt.contains("distinct in both name and behavior"))
    #expect(prompt.contains("instead of replacing them"))
  }
}
