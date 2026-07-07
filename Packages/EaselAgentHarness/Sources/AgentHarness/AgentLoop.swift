import Foundation

public struct AgentLoopConfiguration: Sendable {
  public var maxTurns: Int
  public var allowParallelToolExecution: Bool
  public var noDataTimeout: Duration
  public var contextWindowTokens: Int
  public var outputReserveTokens: Int
  public var temperature: Double?

  public init(
    maxTurns: Int = 20,
    allowParallelToolExecution: Bool = true,
    noDataTimeout: Duration = .seconds(120),
    contextWindowTokens: Int = 32_768,
    outputReserveTokens: Int = 4_096,
    temperature: Double? = nil
  ) {
    self.maxTurns = maxTurns
    self.allowParallelToolExecution = allowParallelToolExecution
    self.noDataTimeout = noDataTimeout
    self.contextWindowTokens = contextWindowTokens
    self.outputReserveTokens = outputReserveTokens
    self.temperature = temperature
  }
}

/// Events emitted by `AgentLoop.run` for the host runtime to render and persist.
public enum AgentLoopEvent: Sendable {
  case turnStarted(index: Int)
  case assistantTextDelta(String)
  case assistantReasoningDelta(String)
  case assistantMessageCompleted(text: String?, toolCalls: [AgentToolCall])
  case toolExecutionStarted(AgentToolCall)
  case toolExecutionCompleted(callId: String, name: String, result: ToolResult)
  /// Cumulative usage across all turns of this run.
  case usageUpdated(AgentTokenUsage)
  /// Emitted after every transcript append; the host persists this for resume.
  case transcriptUpdated(AgentTranscript)
  case completed(finalText: String?)
}

/// The agentic tool-call loop: stream a completion, accumulate tool-call
/// deltas, execute tools (read-only concurrently, mutating serially), append
/// results, repeat until a text-only turn or `maxTurns`.
///
/// Cancellation is cooperative via `Task` cancellation. On cancel, pending
/// tool calls receive synthetic "[cancelled]" error results so the emitted
/// transcript always stays API-valid (providers reject orphaned tool calls).
public actor AgentLoop {
  private let client: any AgentModelClient
  private let tools: [any AgentTool]
  private let configuration: AgentLoopConfiguration
  private let context: ToolExecutionContext

  public init(
    client: any AgentModelClient,
    tools: [any AgentTool],
    configuration: AgentLoopConfiguration,
    context: ToolExecutionContext
  ) {
    self.client = client
    self.tools = tools
    self.configuration = configuration
    self.context = context
  }

  /// Runs the loop to completion, emitting events as they happen.
  /// The final transcript arrives via `.transcriptUpdated` before `.completed`.
  public func run(
    transcript: AgentTranscript,
    model: String
  ) -> AsyncThrowingStream<AgentLoopEvent, Error> {
    // Implementation lands in workstream A. The signature is frozen here so
    // dependent workstreams can build against it.
    AsyncThrowingStream { continuation in
      continuation.finish(
        throwing: AgentHarnessError.malformedResponse("AgentLoop is not implemented yet (workstream A).")
      )
    }
  }
}
