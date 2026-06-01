//
//  TaskGroupView.swift
//  ClaudeCodeUI
//
//  Created on 1/13/2025.
//

import SwiftUI
import CCTerminalServiceInterface

/// View that displays a Task tool with all its nested tool executions in a collapsible format
struct TaskGroupView: View {
  let taskMessage: ChatMessage
  let groupedMessages: [ChatMessage]
  let settingsStorage: SettingsStorage
  let terminalService: TerminalService
  let fontSize: Double
  let viewModel: ChatViewModel
  let showArtifact: ((Artifact) -> Void)?
  
  @Environment(AppearanceSettings.self) private var appearanceSettings
  @Environment(\.colorScheme) private var colorScheme
  
  /// Gets the latest tool status (either executing or last completed)
  var latestToolStatus: (tool: ChatMessage, isExecuting: Bool)? {
    let toolResultsByID = resultByToolUseID(in: groupedMessages)
    let liveToolMessageID = liveToolMessageID(resultByToolUseID: toolResultsByID)

    // First, check if there's a currently executing tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        if message.id == liveToolMessageID {
          // This tool doesn't have a result yet, so it's currently executing
          return (tool: message, isExecuting: true)
        }
      }
    }
    
    // If no executing tool, find the last completed tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        let result = pairedResult(for: message, at: i, resultByToolUseID: toolResultsByID)
        if EaselTimelineToolVisibility.shouldHideToolPair(toolUse: message, toolResult: result) {
          continue
        }
        // This is the most recent tool (must be completed since we checked executing above)
        return (tool: message, isExecuting: false)
      }
    }
    
    return nil
  }
  
  
  /// Pairs tool uses with their corresponding results
  var pairedToolMessages: [(toolUse: ChatMessage, toolResult: ChatMessage?)] {
    var pairs: [(toolUse: ChatMessage, toolResult: ChatMessage?)] = []
    var processedIds = Set<UUID>()
    let toolUseIDs = Set(groupedMessages.compactMap(\.toolUseID).filter { !$0.isEmpty })
    let toolResultsByID = resultByToolUseID(in: groupedMessages)
    let liveToolMessageID = liveToolMessageID(resultByToolUseID: toolResultsByID)
    var i = 0
    
    while i < groupedMessages.count {
      let message = groupedMessages[i]

      if processedIds.contains(message.id) {
        i += 1
        continue
      }
      
      if message.messageType == .toolUse {
        let paired = pairedResult(for: message, at: i, resultByToolUseID: toolResultsByID)
        let result = paired ?? (message.id == liveToolMessageID ? nil : implicitToolResult(for: message))
        if EaselTimelineToolVisibility.shouldHideToolPair(toolUse: message, toolResult: result) {
          processedIds.insert(message.id)
          if let result {
            processedIds.insert(result.id)
          }
          i += 1
          continue
        }
        processedIds.insert(message.id)
        if let result {
          processedIds.insert(result.id)
        }
        pairs.append((toolUse: message, toolResult: result))
      } else if message.messageType == .toolResult || message.messageType == .toolError || message.messageType == .toolDenied {
        if let toolUseID = message.toolUseID, toolUseIDs.contains(toolUseID) {
          processedIds.insert(message.id)
          i += 1
          continue
        }
        if EaselTimelineToolVisibility.shouldHideToolResult(message) {
          processedIds.insert(message.id)
          i += 1
          continue
        }
        // Orphaned result without a tool use - create a placeholder tool use
        let placeholderToolUse = ChatMessage(
          role: .toolUse,
          content: "TOOL USE: Processing",
          messageType: .toolUse,
          toolName: "Processing"
        )
        pairs.append((toolUse: placeholderToolUse, toolResult: message))
      }
      
      i += 1
    }
    
    return pairs
  }

  private func resultByToolUseID(in messages: [ChatMessage]) -> [String: ChatMessage] {
    var results: [String: ChatMessage] = [:]

    for message in messages where message.messageType == .toolResult || message.messageType == .toolError || message.messageType == .toolDenied {
      guard let toolUseID = message.toolUseID, !toolUseID.isEmpty else { continue }
      if results[toolUseID] == nil {
        results[toolUseID] = message
      }
    }

    return results
  }

  private func liveToolMessageID(resultByToolUseID: [String: ChatMessage]) -> UUID? {
    var index = groupedMessages.count - 1

    while index >= 0 {
      let message = groupedMessages[index]

      if message.messageType == .text, message.role == .assistant {
        return nil
      }

      if message.messageType == .toolUse {
        return pairedResult(for: message, at: index, resultByToolUseID: resultByToolUseID) == nil ? message.id : nil
      }

      index -= 1
    }

    return nil
  }

  private func pairedResult(
    for toolUse: ChatMessage,
    at index: Int,
    resultByToolUseID: [String: ChatMessage]
  ) -> ChatMessage? {
    if let toolUseID = toolUse.toolUseID, !toolUseID.isEmpty {
      return resultByToolUseID[toolUseID]
    }

    let nextIndex = index + 1
    guard nextIndex < groupedMessages.count else { return nil }

    let candidate = groupedMessages[nextIndex]
    guard candidate.messageType == .toolResult || candidate.messageType == .toolError || candidate.messageType == .toolDenied else {
      return nil
    }

    if candidate.toolUseID != nil {
      return nil
    }

    return candidate
  }

  private func implicitToolResult(for toolUse: ChatMessage) -> ChatMessage {
    ChatMessage(
      role: .toolResult,
      content: "Completed",
      messageType: .toolResult,
      toolName: toolUse.toolName,
      toolUseID: toolUse.toolUseID
    )
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: EaselChatRuntimeStyle.Spacing.cardContentSpacing) {
      HStack(spacing: EaselChatRuntimeStyle.Spacing.headerDotSpacing) {
        taskStatusIndicator

        if let toolInputData = taskMessage.toolInputData,
           let description = toolInputData.parameters["description"] {
          Text(description)
            .font(EaselChatRuntimeStyle.Typography.primaryTitle)
            .foregroundStyle(.primary)
        } else {
          Text("Task runner")
            .font(EaselChatRuntimeStyle.Typography.primaryTitle)
            .foregroundStyle(.primary)
        }

        Spacer()

        if let status = latestToolStatus, status.isExecuting {
          Text(EaselToolCardPresentation(toolUse: status.tool, toolResult: nil).title)
            .font(EaselChatRuntimeStyle.Typography.secondaryBody.weight(.medium))
            .foregroundStyle(EaselChatRuntimeStyle.running)
            .lineLimit(1)
        } else if pairedToolMessages.count > 0 {
          Text("\(pairedToolMessages.count) steps done")
            .font(EaselChatRuntimeStyle.Typography.secondaryBody)
            .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme, themeColors: appearanceSettings.themeColors))
        }
      }
      .padding(.horizontal, EaselChatRuntimeStyle.Spacing.taskHeaderHorizontal)
      .padding(.vertical, EaselChatRuntimeStyle.Spacing.taskHeaderVertical)
      .background(EaselChatRuntimeStyle.cardBackground(for: colorScheme, themeColors: appearanceSettings.themeColors), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(taskAccessibilityLabel)
      
      if !groupedMessages.isEmpty {
        VStack(alignment: .leading, spacing: EaselChatRuntimeStyle.Spacing.cardContentSpacing) {
          ForEach(Array(pairedToolMessages.enumerated()), id: \.offset) { _, pair in
            EaselToolCardView(
              toolUse: pair.toolUse,
              toolResult: pair.toolResult,
              settingsStorage: settingsStorage,
              terminalService: terminalService,
              fontSize: fontSize,
              viewModel: viewModel,
              showArtifact: showArtifact
            )
          }
        }
      }
      
      // Show cancelled indicator if the task was cancelled
      if taskMessage.wasCancelled {
        Text("Interrupted by user")
          .font(EaselChatRuntimeStyle.Typography.secondaryBody)
          .foregroundStyle(EaselChatRuntimeStyle.failed)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
      }
    }
  }

  @ViewBuilder
  private var taskStatusIndicator: some View {
    if latestToolStatus?.isExecuting == true {
      ProgressView()
        .controlSize(.small)
        .tint(EaselChatRuntimeStyle.running)
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    } else {
      Image(systemName: "checkmark.circle.fill")
        .font(EaselChatRuntimeStyle.Typography.toolIcon)
        .foregroundStyle(EaselChatRuntimeStyle.completedForeground(for: colorScheme, themeColors: appearanceSettings.themeColors))
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
  }

  private var taskAccessibilityLabel: String {
    let title = taskMessage.toolInputData?.parameters["description"] ?? "Task runner"
    if let status = latestToolStatus, status.isExecuting {
      return "\(title), \(EaselToolCardPresentation(toolUse: status.tool, toolResult: nil).title), Working"
    }
    return "\(title), \(pairedToolMessages.count) steps done"
  }
  
}
