//
//  ChatScreen.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import SwiftUI
import CCTerminalServiceInterface
import CCCustomPermissionServiceInterface
import CCCustomPermissionService

/// Main chat interface view that displays the conversation and input controls.
/// 
/// `ChatScreen` serves as the primary user interface for chat interactions with Claude.
/// It manages the display of messages, handles user input, coordinates with various services,
/// and provides a complete chat experience including:
/// - Message history with support for different message types (user, assistant, tool use)
/// - Real-time streaming of responses with token counting
/// - Context management from file references and other sources
/// - Permission approval workflows for sensitive operations
/// - Settings management (both session and global)
/// - Artifact viewing for generated content
/// 
/// This view can be used directly for custom UI implementations without requiring RootView.
/// It's designed to be flexible and configurable through the `UIConfiguration` parameter.
public struct ChatScreen: View {
  
  /// Defines the type of settings to display in the settings sheet
  public enum SettingsType {
    /// Session-specific settings (project path, model, etc.)
    case session
    /// Global application settings
    case global
  }
  
  /// Creates a new ChatScreen instance.
  /// - Parameters:
  ///   - viewModel: The chat view model managing conversation state
  ///   - contextManager: Manages context information from various sources
  ///   - terminalService: Service for terminal operations
  ///   - customPermissionService: Service for custom permission management
  ///   - columnVisibility: Binding to control navigation split view visibility
  ///   - uiConfiguration: UI configuration settings
  public init(
    viewModel: ChatViewModel,
    contextManager: ContextManager,
    terminalService: TerminalService,
    customPermissionService: CustomPermissionService,
    columnVisibility: Binding<NavigationSplitViewVisibility>,
    uiConfiguration: UIConfiguration = .default,
    attachmentImportService: any ChatAttachmentImportService = DefaultChatAttachmentImportService(),
    attachmentProcessingService: any AttachmentProcessingService = AttachmentProcessor()
  ) {
    self.viewModel = viewModel
    self.contextManager = contextManager
    self.terminalService = terminalService
    _customPermissionService = State(initialValue: customPermissionService)
    _columnVisibility = columnVisibility
    self.uiConfiguration = uiConfiguration
    self.attachmentImportService = attachmentImportService
    self.attachmentProcessingService = attachmentProcessingService
  }
  
  /// The view model managing the chat conversation state, messages, and streaming
  /// Handles all chat-related business logic including API interactions
  @State var viewModel: ChatViewModel
  
  /// Manages context information from file references and selected snippets.
  /// Responsible for capturing and providing contextual data to enhance chat interactions
  @State var contextManager: ContextManager
  
  /// Service for executing terminal commands and managing shell operations
  /// Provides interface for running shell scripts and terminal commands
  let terminalService: TerminalService
  
  /// Service managing custom permission requests with approval UI
  /// Handles user approval flow for potentially risky operations
  @State var customPermissionService: CustomPermissionService
  
  /// Configuration object defining UI appearance and behavior
  /// Includes settings like app name, theme, and feature toggles
  let uiConfiguration: UIConfiguration

  let attachmentImportService: any ChatAttachmentImportService
  let attachmentProcessingService: any AttachmentProcessingService
  
  /// Binding controlling the visibility of navigation split view columns
  /// Used to toggle sidebar visibility in the navigation interface
  @Binding var columnVisibility: NavigationSplitViewVisibility
  
  /// The current text in the message input field
  /// Bound to the ChatInputView for user text entry
  @State private var messageText: String = ""
  
  /// Controls the visibility of the settings sheet
  @State var showingSettings = false
  
  /// Determines which type of settings to display (session or global)
  @State var settingsTypeToShow: SettingsType = .session
  
  /// Currently selected artifact for viewing in a sheet
  /// Set when user clicks on an artifact in a message
  @State var artifact: Artifact? = nil
  
  /// Controls the visibility of the delete confirmation dialog
  @State private var showDeleteConfirmation = false

  /// Controls the visibility of the session options dialog (terminal vs new session)
  @State private var showSessionOptions = false

  /// Controls the visibility of the session resumed alert
  @State private var showResumeAlert = false

  /// Global preferences storage for observing default working directory changes
  @Environment(GlobalPreferencesStorage.self) var globalPreferences
  @Environment(\.colorScheme) var colorScheme
  @State var appearanceSettings = AppearanceSettings()

  public var body: some View {
    VStack(spacing: 0) {
      messagesListView
      
      // Loading indicator
      loadingView
      
      ChatInputView(
        text: $messageText,
        chatViewModel: $viewModel,
        contextManager: contextManager,
        uiConfiguration: uiConfiguration,
        placeholder: "Message \(uiConfiguration.appName)...",
        attachmentImportService: attachmentImportService,
        attachmentProcessingService: attachmentProcessingService)
    }
    .background(EaselChatRuntimeStyle.appBackground(for: colorScheme, themeColors: appearanceSettings.themeColors))
    .environment(appearanceSettings)
    .onKeyPress { key in
      // Check for Shift+Tab to cycle permission modes
      if key.modifiers == [.shift] && key.key.character == "\u{19}" {
        let newMode = viewModel.permissionMode.nextMode
        viewModel.permissionMode = newMode
        return .handled
      }
      return .ignored
    }
    .overlay(approvalToastOverlay)
    .overlay(
      errorToastOverlay
        .zIndex(999) // Ensure error toast is on top
    )
    .navigationTitle("")
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    .sheet(isPresented: $showingSettings) {
      settingsSheet
    }
    .sheet(item: $artifact) { artifact in
      ArtifactView(artifact: artifact)
    }
    .alert("Delete Session", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        clearChat()
      }
    } message: {
      if viewModel.activeSessionId != nil {
        Text("Are you sure you want to delete this session? This action cannot be undone.")
      } else {
        Text("Are you sure you want to clear the conversation? This action cannot be undone.")
      }
    }
    .confirmationDialog("Continue Session", isPresented: $showSessionOptions) {
      Button("Resume in New Session") {
        resumeInNewSession()
      }
      Button("Follow on Terminal") {
        if let sessionId = viewModel.activeSessionId {
          launchTerminalWithSession(sessionId)
        }
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Choose how to continue this conversation")
    }
    .alert("Session Resumed!", isPresented: $showResumeAlert) {
      // No buttons - will auto-dismiss
    } message: {
      Text("You can now continue your conversation")
    }
  }
  
  // MARK: - Subviews
  
  @ViewBuilder
  private var errorToastOverlay: some View {
    ErrorToastContainer(
      errorQueue: $viewModel.errorQueue,
      onRetry: {
        // Retry the last message with all its original data
        viewModel.retryLastMessage()
      },
      isDebugEnabled: viewModel.isDebugEnabled
    )
  }
  
  @ViewBuilder
  private var loadingView: some View {
    let isToastVisible = (customPermissionService as? DefaultCustomPermissionService)?.isToastVisible ?? false
    if viewModel.isLoading, !isToastVisible, let startTime = viewModel.streamingStartTime {
      LoadingIndicator(
        startTime: startTime,
        inputTokens: viewModel.currentInputTokens,
        outputTokens: viewModel.currentOutputTokens,
        costUSD: viewModel.currentCostUSD,
        showTokenCount: uiConfiguration.showTokenCount,
        activityText: EaselToolCardPresentation.activeActivityTitle(in: viewModel.messages) ?? "Easel is working"
      )
      .padding(.horizontal)
      .padding(.bottom, 8)
      .transition(.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
      ))
    }
  }
  
  @ViewBuilder
  private var approvalToastOverlay: some View {
    if let permissionService = customPermissionService as? DefaultCustomPermissionService {
      ToastContainer(isPresented: .constant(permissionService.isToastVisible)) {
        if let request = permissionService.currentToastRequest {
        ApprovalToast(
          request: request,
          showRiskData: uiConfiguration.showRiskData,
          queueCount: permissionService.approvalQueue.count,
          onApprove: {
            permissionService.approveCurrentToast()
            // Find and collapse the tool message that was just approved
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onDeny: {
            permissionService.denyCurrentToast()
            // Find and collapse the tool message that was just denied
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onDenyWithGuidance: { guidance in
            permissionService.denyCurrentToastWithGuidance(guidance)
            // Find and collapse the tool message that was just denied
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onCancel: {
            // Cancel the stream entirely - same as pressing escape
            viewModel.cancelRequest()
            // Also hide the toast
            permissionService.denyCurrentToast()
            // Find and collapse the tool message that was just cancelled
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          }
        )
      }
    }
    }
  }
  
  /// Find the most recent tool message that matches the current approval request
  private func findCurrentToolMessage() -> ChatMessage? {
    guard let permissionService = customPermissionService as? DefaultCustomPermissionService,
          let request = permissionService.currentToastRequest else { return nil }
    
    // Look for the most recent tool message with matching toolName
    // Iterate from end (most recent) to find the matching tool
    return viewModel.messages.reversed().first { message in
      message.messageType == .toolUse &&
      message.toolName == request.toolName &&
      // Only collapse Edit, MultiEdit, Write tools (the ones with diffs)
      ["Edit", "MultiEdit", "Write"].contains(message.toolName ?? "")
    }
  }
  
  @ViewBuilder
  private var settingsSheet: some View {
    switch settingsTypeToShow {
    case .session:
      SettingsView(chatViewModel: viewModel)
    case .global:
      GlobalSettingsView(
        uiConfiguration: uiConfiguration,
        chatViewModel: viewModel,
        mcpToolsDiscovery: viewModel.mcpToolsDiscovery
      )
    }
  }
  
  // MARK: - Actions
  
  private func clearChat() {
    Task {
      // If we have an active session, properly delete it from database
      if let sessionId = viewModel.activeSessionId {
        await viewModel.deleteSession(id: sessionId)
      } else {
        // No saved session, just clear the UI
        viewModel.clearConversation()
      }
    }
  }
  
  private func resumeInNewSession() {
    guard let sessionId = viewModel.activeSessionId else { return }

    // Get the current working directory
    let workingDirectory = viewModel.projectPath

    // Clear the current conversation UI (removes all visible messages)
    viewModel.clearConversation()

    // Keep the session ID active so next message continues this conversation
    viewModel.sessionManager.selectSession(id: sessionId)

    // Set the working directory
    if !workingDirectory.isEmpty {
      viewModel.setWorkingDirectory(workingDirectory)
    }

    // Show success alert
    showResumeAlert = true

    // Auto-dismiss alert after 1.5 seconds
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.5))
      showResumeAlert = false
    }

  }

  private func launchTerminalWithSession(_ sessionId: String) {
    guard viewModel.activeProvider == .claude else {
      let error = NSError(
        domain: "ChatScreen",
        code: 1002,
        userInfo: [NSLocalizedDescriptionKey: "Terminal handoff is only available for Claude sessions."]
      )
      viewModel.errorInfo = ErrorInfo.fileError(error, fileName: "Terminal launch")
      viewModel.errorQueue.append(viewModel.errorInfo!)
      return
    }

    // Use the TerminalLauncher helper to launch Terminal
    if let error = TerminalLauncher.launchTerminalWithSession(
      sessionId,
      claudeClient: viewModel.claudeClient,
      projectPath: viewModel.projectPath
    ) {
      viewModel.errorInfo = ErrorInfo.fileError(error, fileName: "Terminal launch")
      viewModel.errorQueue.append(viewModel.errorInfo!)
    } else {
    }
  }
}
