//
//  ChatScreen+MessagesList.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

extension ChatScreen {
  
  /// Enum to represent different types of message items after grouping
  enum MessageItem: Identifiable {
    case single(ChatMessage)
    case taskGroup(taskMessage: ChatMessage, groupedMessages: [ChatMessage])
    case toolPair(toolUse: ChatMessage, toolResult: ChatMessage?)
    
    var id: UUID {
      switch self {
      case .single(let message):
        return message.id
      case .taskGroup(let taskMessage, _):
        return taskMessage.id
      case .toolPair(let toolUse, _):
        return toolUse.id
      }
    }
  }
  
  /// Groups messages by taskGroupId for display
  var groupedMessageItems: [MessageItem] {
    var items: [MessageItem] = []
    var processedIds = Set<UUID>()
    var taskGroups: [UUID: (task: ChatMessage, messages: [ChatMessage])] = [:]
    
    // First pass: identify all task groups
    for message in viewModel.messages {
      if let groupId = message.taskGroupId {
        if message.isTaskContainer {
          // This is the Task message that starts the group
          taskGroups[groupId] = (task: message, messages: [])
        } else if var group = taskGroups[groupId] {
          // Add to existing group
          group.messages.append(message)
          taskGroups[groupId] = group
        }
      }
    }
    
    // Second pass: create message items, pairing top-level tool calls with their result when possible.
    var index = 0
    while index < viewModel.messages.count {
      let message = viewModel.messages[index]
      // Skip if already processed as part of a group
      if processedIds.contains(message.id) {
        index += 1
        continue
      }
      
      if let groupId = message.taskGroupId,
         message.isTaskContainer,
         let group = taskGroups[groupId] {
        // Include ALL messages in the group
        items.append(.taskGroup(taskMessage: message, groupedMessages: group.messages))
        
        processedIds.insert(message.id)
        // Mark ALL messages in the group as processed
        for groupedMessage in group.messages {
          processedIds.insert(groupedMessage.id)
        }
        index += 1
      } else if message.taskGroupId != nil {
        processedIds.insert(message.id)
        index += 1
      } else if message.messageType == .toolUse {
        let toolResult = pairedResult(after: index)
        items.append(.toolPair(toolUse: message, toolResult: toolResult))
        processedIds.insert(message.id)
        if let toolResult {
          processedIds.insert(toolResult.id)
        }
        index += toolResult == nil ? 1 : 2
      } else if message.isToolResultLike {
        items.append(.toolPair(toolUse: message, toolResult: nil))
        processedIds.insert(message.id)
        index += 1
      } else if message.taskGroupId == nil {
        // Regular message not part of any group
        items.append(.single(message))
        processedIds.insert(message.id)
        index += 1
      } else {
        index += 1
      }
    }
    
    return items
  }

  private func pairedResult(after index: Int) -> ChatMessage? {
    let nextIndex = index + 1
    guard nextIndex < viewModel.messages.count else { return nil }

    let toolUse = viewModel.messages[index]
    let candidate = viewModel.messages[nextIndex]

    guard candidate.taskGroupId == nil, candidate.isToolResultLike else { return nil }

    if let toolName = toolUse.toolName, let candidateToolName = candidate.toolName {
      return toolName == candidateToolName ? candidate : nil
    }

    return candidate
  }
  
  /// Determines the effective working directory based on manual selection or global default
  var effectiveWorkingDirectory: String? {
    // First priority: manually set project path for the session
    if !viewModel.projectPath.isEmpty {
      return "cwd: \(viewModel.projectPath)"
    }

    // Second priority: global default working directory
    if !globalPreferences.defaultWorkingDirectory.isEmpty {
      return "cwd: \(globalPreferences.defaultWorkingDirectory)"
    }

    return nil
  }
  
  /// Determines whether to show the settings button
  var shouldShowSettingsButton: Bool {
    // Show settings button when there's no working directory
    return effectiveWorkingDirectory == nil
  }
  
  var messagesListView: some View {
    ScrollViewReader { scrollView in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: EaselChatRuntimeStyle.Spacing.messageListSpacing) {
          if uiConfiguration.showWelcomeRow && (viewModel.messages.isEmpty || shouldShowSettingsButton) {
            WelcomeRow(
              path: effectiveWorkingDirectory,
              showSettingsButton: shouldShowSettingsButton,
              appName: uiConfiguration.appName,
              toolTip: uiConfiguration.workingDirectoryToolTip,
              generalInstructionsTip: uiConfiguration.generalInstructionsTip,
              appIconAssetName: uiConfiguration.appIconAssetName,
              hasMessages: !viewModel.messages.isEmpty,
              onSettingsTapped: {
                settingsTypeToShow = .session
                showingSettings = true
              },
              onWorktreeSelected: { worktreePath in
                // Update the current session's working directory to the selected worktree
                viewModel.setWorkingDirectory(worktreePath)
              }
            )
            .id("welcome-row")
          }

          ForEach(groupedMessageItems) { item in
            messageItemView(item)
          }
        }
        .frame(maxWidth: EaselChatRuntimeStyle.maxContentWidth, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
      }
      .background(EaselChatRuntimeStyle.appBackground(for: colorScheme, themeColors: appearanceSettings.themeColors))
      .onChange(of: viewModel.messages) { _,_ in
        // Scroll to bottom when new messages are added
        if let lastMessage = viewModel.messages.last {
          withAnimation {
            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
      .onChange(of: globalPreferences.defaultWorkingDirectory) { _, _ in
        // Update the current session's working directory if there's no session-specific path
        let newDefault = globalPreferences.defaultWorkingDirectory
        if viewModel.projectPath.isEmpty && !newDefault.isEmpty {
          // Update all components to use the new default directory
          viewModel.setWorkingDirectory(newDefault)
        }
      }
    }
  }

  @ViewBuilder
  private func messageItemView(_ item: MessageItem) -> some View {
    switch item {
    case .single(let message):
      ChatMessageView(
        message: message,
        settingsStorage: viewModel.settingsStorage,
        terminalService: terminalService,
        fontSize: uiConfiguration.messageFontSize,
        viewModel: viewModel,
        assistantName: uiConfiguration.appName,
        showArtifact: { artifactItem in
          artifact = artifactItem
        }
      )
      .id(message.id)

    case .taskGroup(let taskMessage, let groupedMessages):
      TaskGroupView(
        taskMessage: taskMessage,
        groupedMessages: groupedMessages,
        settingsStorage: viewModel.settingsStorage,
        terminalService: terminalService,
        fontSize: uiConfiguration.messageFontSize,
        viewModel: viewModel,
        showArtifact: { artifactItem in
          artifact = artifactItem
        }
      )
      .id(taskMessage.id)

    case .toolPair(let toolUse, let toolResult):
      EaselToolCardView(
        toolUse: toolUse,
        toolResult: toolResult,
        settingsStorage: viewModel.settingsStorage,
        terminalService: terminalService,
        fontSize: uiConfiguration.messageFontSize,
        viewModel: viewModel,
        showArtifact: { artifactItem in
          artifact = artifactItem
        }
      )
      .id(toolUse.id)
    }
  }
}

private extension ChatMessage {
  var isToolResultLike: Bool {
    messageType == .toolResult || messageType == .toolError || messageType == .toolDenied
  }
}
