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
  
  @Environment(\.colorScheme) private var colorScheme
  
  /// Gets the latest tool status (either executing or last completed)
  var latestToolStatus: (tool: ChatMessage, isExecuting: Bool)? {
    // First, check if there's a currently executing tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        // Check if this tool has a result
        var hasResult = false
        if i + 1 < groupedMessages.count {
          let nextMessage = groupedMessages[i + 1]
          if nextMessage.messageType == .toolResult || nextMessage.messageType == .toolError || nextMessage.messageType == .toolDenied {
            hasResult = true
          }
        }
        
        if !hasResult {
          // This tool doesn't have a result yet, so it's currently executing
          return (tool: message, isExecuting: true)
        }
      }
    }
    
    // If no executing tool, find the last completed tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        // This is the most recent tool (must be completed since we checked executing above)
        return (tool: message, isExecuting: false)
      }
    }
    
    return nil
  }
  
  
  /// Pairs tool uses with their corresponding results
  var pairedToolMessages: [(toolUse: ChatMessage, toolResult: ChatMessage?)] {
    var pairs: [(toolUse: ChatMessage, toolResult: ChatMessage?)] = []
    var i = 0
    
    while i < groupedMessages.count {
      let message = groupedMessages[i]
      
      if message.messageType == .toolUse {
        // Look for the next message to see if it's a result
        var result: ChatMessage? = nil
        if i + 1 < groupedMessages.count {
          let nextMessage = groupedMessages[i + 1]
          if nextMessage.messageType == .toolResult || nextMessage.messageType == .toolError || nextMessage.messageType == .toolDenied {
            result = nextMessage
            i += 1 // Skip the result in the next iteration
          }
        }
        pairs.append((toolUse: message, toolResult: result))
      } else if message.messageType == .toolResult || message.messageType == .toolError || message.messageType == .toolDenied {
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
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Circle()
          .fill(EaselChatRuntimeStyle.completed)
          .frame(width: 6, height: 6)

        if let toolInputData = taskMessage.toolInputData,
           let description = toolInputData.parameters["description"] {
          Text(description)
            .font(.callout.bold())
            .foregroundStyle(.primary)
        } else {
          Text("Task runner")
            .font(.callout.bold())
            .foregroundStyle(.primary)
        }
        
        Spacer()

        if let status = latestToolStatus, status.isExecuting {
          Text("running")
            .font(.caption)
            .foregroundStyle(EaselChatRuntimeStyle.running)
        } else if pairedToolMessages.count > 0 {
          Text("\(pairedToolMessages.count) tools")
            .font(.caption)
            .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(EaselChatRuntimeStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
      
      if !groupedMessages.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
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
          .font(.caption)
          .foregroundStyle(EaselChatRuntimeStyle.failed)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
      }
    }
  }
  
  private var headerBackgroundColor: Color {
    colorScheme == .dark
      ? Color.expandedContentBackgroundDark.opacity(0.6)
      : Color.expandedContentBackgroundLight.opacity(0.6)
  }
  
  private var borderColor: Color {
    colorScheme == .dark
      ? Color(white: 0.25)
      : Color(white: 0.85)
  }
}
