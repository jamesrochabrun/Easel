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
  /// The transcript to persist for resume. Invariant: every emitted
  /// transcript is API-valid on its own — an assistant tool-call message is
  /// never published without its tool results, so the host can persist each
  /// one blindly and cancel consumption at any moment without corrupting
  /// the stored conversation.
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
    let (stream, continuation) = AsyncThrowingStream<AgentLoopEvent, Error>.makeStream()
    let task = Task {
      do {
        try await execute(transcript: transcript, model: model, emit: continuation)
        continuation.finish()
      } catch is CancellationError {
        continuation.finish(throwing: AgentHarnessError.cancelled)
      } catch {
        continuation.finish(throwing: error)
      }
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }

  // MARK: - Loop body

  private func execute(
    transcript initial: AgentTranscript,
    model: String,
    emit: AsyncThrowingStream<AgentLoopEvent, Error>.Continuation
  ) async throws {
    var transcript = initial
    var cumulativeUsage = AgentTokenUsage()
    let schemas = tools.map {
      AgentToolSchema(name: $0.name, description: $0.description, parameters: $0.parametersJSONSchema)
    }
    let toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    let capabilities = client.capabilities

    for turn in 0..<configuration.maxTurns {
      try Task.checkCancellation()
      emit.yield(.turnStarted(index: turn))

      let outgoing = try TranscriptTrimmer.trim(
        transcript,
        budgetTokens: configuration.contextWindowTokens - configuration.outputReserveTokens
      )

      let useStreaming = capabilities.supportsStreaming
        && (schemas.isEmpty || capabilities.supportsStreamingToolCalls)
      let request = AgentModelRequest(
        model: model,
        messages: outgoing.messages,
        tools: schemas,
        temperature: configuration.temperature,
        parallelToolCalls: capabilities.supportsParallelToolCalls,
        stream: useStreaming
      )

      // Consume one completion.
      var textBuffer = ""
      var accumulator = ToolCallAccumulator()
      var turnUsage: AgentTokenUsage?

      let events = Self.enforcingNoDataTimeout(
        try await client.streamCompletion(request),
        timeout: configuration.noDataTimeout
      )
      do {
        for try await event in events {
          try Task.checkCancellation()
          switch event {
          case .textDelta(let delta):
            textBuffer += delta
            emit.yield(.assistantTextDelta(delta))
          case .reasoningDelta(let delta):
            emit.yield(.assistantReasoningDelta(delta))
          case .toolCallDelta(let index, let id, let name, let fragment):
            accumulator.ingest(index: index, id: id, name: name, fragment: fragment)
          case .usage(let usage):
            turnUsage = usage
          case .finish:
            break
          }
        }
      } catch {
        // Cancelled mid-stream: persist the partial text (without incomplete
        // tool calls) so the transcript stays valid, then rethrow.
        if error is CancellationError || (error as? AgentHarnessError) == .cancelled {
          if !textBuffer.isEmpty {
            transcript.messages.append(.assistant(text: textBuffer, toolCalls: []))
            emit.yield(.transcriptUpdated(transcript))
          }
        }
        throw error
      }
      // Iteration also ends silently when the consuming task is cancelled.
      if Task.isCancelled {
        if !textBuffer.isEmpty {
          transcript.messages.append(.assistant(text: textBuffer, toolCalls: []))
          emit.yield(.transcriptUpdated(transcript))
        }
        throw CancellationError()
      }

      if let turnUsage {
        cumulativeUsage.inputTokens += turnUsage.inputTokens
        cumulativeUsage.outputTokens += turnUsage.outputTokens
        cumulativeUsage.cachedInputTokens += turnUsage.cachedInputTokens
        emit.yield(.usageUpdated(cumulativeUsage))
      }

      let toolCalls = accumulator.finalize()
      let assistantText = textBuffer.isEmpty ? nil : textBuffer
      transcript.messages.append(.assistant(text: assistantText, toolCalls: toolCalls))
      emit.yield(.assistantMessageCompleted(text: assistantText, toolCalls: toolCalls))

      guard !toolCalls.isEmpty else {
        emit.yield(.transcriptUpdated(transcript))
        emit.yield(.completed(finalText: assistantText))
        return
      }

      // Execute tools; results are appended in original call order. The
      // assistant tool-call message and its results are published in ONE
      // transcriptUpdated so no observable transcript ever dangles.
      let results = await executeToolCalls(toolCalls, toolsByName: toolsByName, emit: emit)
      for (call, result) in zip(toolCalls, results) {
        transcript.messages.append(
          .tool(callId: call.id, name: call.name, content: result.content, isError: result.isError)
        )
      }
      emit.yield(.transcriptUpdated(transcript))

      try Task.checkCancellation()
    }

    transcript.messages.append(
      .assistant(
        text: "[Stopped: reached the maximum of \(configuration.maxTurns) tool-use turns without a final answer.]",
        toolCalls: []
      )
    )
    emit.yield(.transcriptUpdated(transcript))
    throw AgentHarnessError.maxTurnsExceeded(configuration.maxTurns)
  }

  // MARK: - Tool execution

  /// Read-only tools run concurrently (when allowed); mutating or unknown
  /// tools run serially in call order afterwards. If cancellation lands
  /// mid-batch, every unfinished call gets a "[cancelled]" error result so
  /// the transcript the caller appends stays API-valid.
  private func executeToolCalls(
    _ calls: [AgentToolCall],
    toolsByName: [String: any AgentTool],
    emit: AsyncThrowingStream<AgentLoopEvent, Error>.Continuation
  ) async -> [ToolResult] {
    var results = [ToolResult?](repeating: nil, count: calls.count)

    let readOnlyIndices = calls.indices.filter { toolsByName[calls[$0].name]?.isReadOnly == true }
    let serialIndices = calls.indices.filter { !readOnlyIndices.contains($0) }

    if configuration.allowParallelToolExecution, readOnlyIndices.count > 1 {
      for index in readOnlyIndices {
        emit.yield(.toolExecutionStarted(calls[index]))
      }
      await withTaskGroup(of: (Int, ToolResult).self) { group in
        for index in readOnlyIndices {
          let call = calls[index]
          let tool = toolsByName[call.name]
          group.addTask { [context] in
            (index, await Self.executeSingle(call: call, tool: tool, context: context))
          }
        }
        for await (index, result) in group {
          results[index] = result
          emit.yield(.toolExecutionCompleted(callId: calls[index].id, name: calls[index].name, result: result))
        }
      }
    } else {
      for index in readOnlyIndices {
        let call = calls[index]
        emit.yield(.toolExecutionStarted(call))
        let result = await Self.executeSingle(call: call, tool: toolsByName[call.name], context: context)
        results[index] = result
        emit.yield(.toolExecutionCompleted(callId: call.id, name: call.name, result: result))
      }
    }

    for index in serialIndices {
      let call = calls[index]
      if Task.isCancelled {
        break
      }
      emit.yield(.toolExecutionStarted(call))
      let result = await Self.executeSingle(call: call, tool: toolsByName[call.name], context: context)
      results[index] = result
      emit.yield(.toolExecutionCompleted(callId: call.id, name: call.name, result: result))
    }

    return results.enumerated().map { index, result in
      if let result {
        return result
      }
      let cancelled = ToolResult(content: "[cancelled]", isError: true)
      emit.yield(.toolExecutionCompleted(callId: calls[index].id, name: calls[index].name, result: cancelled))
      return cancelled
    }
  }

  private static func executeSingle(
    call: AgentToolCall,
    tool: (any AgentTool)?,
    context: ToolExecutionContext
  ) async -> ToolResult {
    guard let tool else {
      return ToolResult(
        content: "Unknown tool \"\(call.name)\". Use only the tools provided in this conversation.",
        isError: true
      )
    }
    let arguments: JSONValue
    do {
      arguments = try JSONValue(parsing: call.arguments)
    } catch {
      return ToolResult(
        content: "Arguments for \(call.name) were not valid JSON (\(error.localizedDescription)). Resend the call with a valid JSON object.",
        isError: true
      )
    }
    do {
      return try await tool.execute(arguments: arguments, context: context)
    } catch is CancellationError {
      return ToolResult(content: "[cancelled]", isError: true)
    } catch {
      return ToolResult(
        content: "\(call.name) failed: \(error.localizedDescription)",
        isError: true
      )
    }
  }

  // MARK: - No-data timeout

  /// Wraps an event stream so that a silence longer than `timeout` fails the
  /// stream with `.streamTimeout` (parity with the CLI providers' watchdog).
  private static func enforcingNoDataTimeout(
    _ upstream: AsyncThrowingStream<AgentModelEvent, Error>,
    timeout: Duration
  ) -> AsyncThrowingStream<AgentModelEvent, Error> {
    AsyncThrowingStream { continuation in
      let activity = StreamActivityClock()
      let forward = Task {
        do {
          for try await event in upstream {
            await activity.touch()
            continuation.yield(event)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      let watchdog = Task {
        while !Task.isCancelled {
          let elapsed = await activity.timeSinceLastEvent()
          let remaining = timeout - elapsed
          if remaining <= .zero {
            forward.cancel()
            continuation.finish(
              throwing: AgentHarnessError.streamTimeout(seconds: Int(timeout.components.seconds))
            )
            return
          }
          do {
            try await Task.sleep(for: remaining)
          } catch {
            return
          }
        }
      }
      continuation.onTermination = { _ in
        forward.cancel()
        watchdog.cancel()
      }
    }
  }
}

private actor StreamActivityClock {
  private var last = ContinuousClock.now

  func touch() {
    last = .now
  }

  func timeSinceLastEvent() -> Duration {
    last.duration(to: .now)
  }
}
