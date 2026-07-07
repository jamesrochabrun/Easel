import Foundation

/// Fits a transcript into a token budget without ever producing an
/// API-invalid message sequence.
///
/// Policy, in order:
/// 1. Elide the bodies of the oldest tool results (cheap wins first).
/// 2. Drop whole turn groups from the oldest forward — an assistant message
///    and its tool results always travel together, so a tool result is never
///    orphaned from its call.
/// The system message and the last user message (and everything after it)
/// are never touched. If the irreducible minimum still exceeds the budget,
/// throws `contextWindowExceeded`.
public enum TranscriptTrimmer {
  public static let elisionMarker = "[output elided to save context]"

  public static func trim(_ transcript: AgentTranscript, budgetTokens: Int) throws -> AgentTranscript {
    guard TokenEstimator.estimateTokens(in: transcript) > budgetTokens else {
      return transcript
    }

    var groups = makeGroups(from: transcript.messages)
    let lastUserGroupIndex = groups.lastIndex { $0.isUser }

    func isProtected(_ index: Int) -> Bool {
      if groups[index].isSystem { return true }
      guard let lastUser = lastUserGroupIndex else { return false }
      return index >= lastUser
    }

    func currentEstimate() -> Int {
      groups.flatMap(\.messages).reduce(0) { $0 + TokenEstimator.estimateTokens(in: $1) }
    }

    // Pass 1: elide old tool-result bodies.
    for index in groups.indices where !isProtected(index) {
      guard currentEstimate() > budgetTokens else { break }
      groups[index].elideToolResults()
    }

    // Pass 2: drop whole unprotected groups, oldest first.
    var dropped = Set<Int>()
    for index in groups.indices where !isProtected(index) {
      guard currentEstimate() - droppedTokens(groups, dropped) > budgetTokens else { break }
      dropped.insert(index)
    }

    let remaining = groups.indices
      .filter { !dropped.contains($0) }
      .flatMap { groups[$0].messages }

    let trimmed = AgentTranscript(version: transcript.version, messages: remaining)
    let finalEstimate = TokenEstimator.estimateTokens(in: trimmed)
    guard finalEstimate <= budgetTokens else {
      throw AgentHarnessError.contextWindowExceeded(estimated: finalEstimate, limit: budgetTokens)
    }
    return trimmed
  }

  // MARK: - Grouping

  private struct Group {
    var messages: [AgentMessage]
    var isSystem = false
    var isUser = false

    mutating func elideToolResults() {
      messages = messages.map { message in
        guard case .tool(let callId, let name, let content, let isError) = message,
              content != TranscriptTrimmer.elisionMarker
        else { return message }
        // Keep errors visible — they're short and steer the model.
        guard !isError else { return message }
        return .tool(callId: callId, name: name, content: TranscriptTrimmer.elisionMarker, isError: isError)
      }
    }
  }

  private static func makeGroups(from messages: [AgentMessage]) -> [Group] {
    var groups: [Group] = []
    for message in messages {
      switch message {
      case .system:
        groups.append(Group(messages: [message], isSystem: true))
      case .user:
        groups.append(Group(messages: [message], isUser: true))
      case .assistant:
        groups.append(Group(messages: [message]))
      case .tool:
        // Tool results always follow their assistant tool-call message, so
        // they join the previous group and can never be dropped without it.
        if groups.isEmpty {
          groups.append(Group(messages: [message]))
        } else {
          groups[groups.count - 1].messages.append(message)
        }
      }
    }
    return groups
  }

  private static func droppedTokens(_ groups: [Group], _ dropped: Set<Int>) -> Int {
    dropped.reduce(0) { sum, index in
      sum + groups[index].messages.reduce(0) { $0 + TokenEstimator.estimateTokens(in: $1) }
    }
  }
}
