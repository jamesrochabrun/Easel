import SwiftUI
import CCTerminalServiceInterface

// MARK: - JSON Keys
private enum JSONKeys {
  static let filePath = "file_path"
  static let content = "content"
}

/// A view that renders the content of a chat message with appropriate formatting based on the message type.
///
/// This view handles different message types including:
/// - Plain text messages from users and assistants
/// - Tool usage messages with specialized native detail views where needed
/// - Tool results and errors
/// - Thinking messages
/// - Web search results
///
/// The view automatically selects the appropriate rendering strategy:
/// - Collapsible content for tool-related messages
/// - Formatted text for assistant responses
/// - Plain text for user messages
/// - Specialized native views for approval and file-write tool content
///
/// ## Usage Example
/// ```swift
/// MessageContentView(
///     message: chatMessage,
///     fontSize: 14.0,
///     horizontalPadding: 16.0,
///     maxWidth: 600.0,
///     terminalService: terminalService
/// )
/// ```

struct MessageContentView: View {
  /// The chat message to display.
  /// Contains the message content, role (user/assistant/system), type (text/toolUse/toolResult/etc),
  /// and associated metadata such as tool parameters and results.
  let message: ChatMessage
  
  /// Base font size for message content in points.
  /// This value is used as the foundation for all text rendering,
  /// with relative adjustments made for headers, code blocks, etc.
  let fontSize: Double
  
  /// Horizontal padding applied to message content.
  /// Creates consistent spacing between the message content and container edges.
  /// Typically ranges from 12-20 points depending on the UI design.
  let horizontalPadding: CGFloat
  
  /// Optional callback to show artifacts like Mermaid diagrams
  let showArtifact: ((Artifact) -> Void)?
  
  /// Maximum width constraint for the message content.
  /// Prevents messages from becoming too wide on large screens,
  /// ensuring optimal readability. Usually set based on the container width.
  let maxWidth: CGFloat
  
  /// Terminal service retained for tool renderers that need command execution.
  let terminalService: TerminalService
  
  /// The project path for file operations
  let projectPath: String?
  
  /// Optional callback when approval/denial action occurs
  let onApprovalAction: (() -> Void)?

  /// View model for handling approval actions
  let viewModel: ChatViewModel?
  
  /// Current color scheme for adaptive styling.
  /// Used to adjust text colors and font weights for optimal readability
  /// in both light and dark modes.
  @Environment(\.colorScheme) private var colorScheme
  
  /// Creates a new message content view with the specified configuration.
  ///
  /// - Parameters:
  ///   - message: The chat message to display, containing content, role, and metadata
  ///   - fontSize: Base font size in points for message content
  ///   - horizontalPadding: Padding between message content and container edges
  ///   - showArtifact: Optional callback to display artifacts like Mermaid diagrams
  ///   - maxWidth: Maximum width constraint to ensure optimal readability
  ///   - terminalService: Service for tool renderers that need command execution
  ///   - projectPath: Optional project directory path for file operations
  ///   - onApprovalAction: Optional callback invoked when user approves/denies tool actions
  ///   - viewModel: Optional view model for handling approval actions
  init(
    message: ChatMessage,
    fontSize: Double,
    horizontalPadding: CGFloat,
    showArtifact: ((Artifact) -> Void)?,
    maxWidth: CGFloat,
    terminalService: TerminalService,
    projectPath: String?,
    onApprovalAction: (() -> Void)? = nil,
    viewModel: ChatViewModel? = nil
  ) {
    self.message = message
    self.fontSize = fontSize
    self.horizontalPadding = horizontalPadding
    self.showArtifact = showArtifact
    self.maxWidth = maxWidth
    self.terminalService = terminalService
    self.projectPath = projectPath
    self.onApprovalAction = onApprovalAction
    self.viewModel = viewModel
  }
  
  /// Determines if the message type should be displayed in a collapsible format.
  /// Tool-related messages (toolUse, toolResult, toolError, toolDenied, thinking, webSearch, codeExecution) are collapsible,
  /// while plain text messages are not.
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .toolDenied, .thinking, .webSearch, .codeExecution:
      return true
    case .text:
      return false
    }
  }

  var body: some View {
    contentView
  }
  
  @ViewBuilder
  private var contentView: some View {
    if isCollapsible {
      collapsibleContent
    } else if message.role == .assistant && message.messageType == .text {
      markdownTextContent
    } else {
      plainTextContent
    }
  }

  @ViewBuilder
  private var markdownTextContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      EaselMarkdownMessageView(
        content: message.content,
        role: message.role,
        fontSize: CGFloat(fontSize),
        isComplete: message.isComplete,
        showArtifact: showArtifact
      )
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, 8)

      if !message.isComplete && message.content.isEmpty {
        MessageLoadingIndicator(messageTint: messageTint)
      }

      if message.wasCancelled {
        cancelledIndicator
      }
    }
  }
  
  @ViewBuilder
  private var collapsibleContent: some View {
    Group {
      // Check for ExitPlanMode tool - render inline approval UI
      if message.messageType == .toolUse,
         (message.toolName == "exit_plan_mode" || message.toolName == "ExitPlanMode"),
         let viewModel = viewModel,
         let planContent = message.toolInputData?.parameters["plan"] {
        InlinePlanApprovalView(
          messageId: message.id,
          planContent: planContent,
          viewModel: viewModel,
          isResolved: message.planApprovalStatus != nil,
          approvalStatus: message.planApprovalStatus
        )
        .padding(.horizontal, horizontalPadding)
      }
      // Check if this is an Edit, MultiEdit, or Write tool message with tool input data
      else if message.messageType == .toolUse,
         let rawParams = message.toolInputData?.rawParameters {

        switch message.toolName {
        case "Edit":
          editToolContent(rawParams: rawParams)
        case "MultiEdit":
          multiEditToolContent(rawParams: rawParams)
        case "Write":
          writeToolContent(rawParams: rawParams)
        default:
          defaultToolDisplay
        }
      } else {
        defaultToolDisplay
      }
    }
  }
  
  // MARK: - Tool Content Views
  
  @ViewBuilder
  private func editToolContent(rawParams _: [String: String]) -> some View {
    defaultToolDisplay
  }
  
  @ViewBuilder
  private func multiEditToolContent(rawParams _: [String: String]) -> some View {
    defaultToolDisplay
  }
  
  @ViewBuilder
  private func writeToolContent(rawParams: [String: String]) -> some View {
    if let filePath = rawParams[JSONKeys.filePath],
       let content = rawParams[JSONKeys.content] {
      WriteToolContentView(
        content: content,
        filePath: filePath,
        fontSize: fontSize
      )
    } else {
      defaultToolDisplay
    }
  }

  /// Default display for tool messages that don't have specialized views.
  /// Uses ToolDisplayView for consistent formatting of tool parameters and results.
  @ViewBuilder
  private var defaultToolDisplay: some View {
    // Use the new ToolDisplayView for sophisticated formatting
    ToolDisplayView(
      message: message,
      fontSize: fontSize
    )
  }
  
  @ViewBuilder
  private var plainTextContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      let displayContent = message.role == .user && !message.content.isEmpty ? "\(message.content)" : message.content
      Text(displayContent)
        .textSelection(.enabled)
        .font(messageFont)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
      
      // Show cancelled indicator if message was cancelled
      if message.wasCancelled {
        cancelledIndicator
      }
    }
  }

  private var cancelledIndicator: some View {
    HStack {
      Text("Interrupted by user")
        .font(.system(size: fontSize - 1))
        .foregroundColor(.red)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
    }
  }

  private var messageTint: SwiftUI.Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? EaselChatRuntimeStyle.secondaryText(for: colorScheme) : .primary
    case .toolUse:
      return SwiftUI.Color(red: 255/255, green: 149/255, blue: 0/255)
    case .toolResult:
      return SwiftUI.Color(red: 52/255, green: 199/255, blue: 89/255)
    case .toolError:
      return SwiftUI.Color(red: 255/255, green: 59/255, blue: 48/255)
    case .toolDenied:
      return SwiftUI.Color.secondary
    case .thinking:
      return SwiftUI.Color(red: 90/255, green: 200/255, blue: 250/255)
    case .webSearch:
      return SwiftUI.Color(red: 0/255, green: 199/255, blue: 190/255)
    case .codeExecution:
      return EaselChatRuntimeStyle.running
    }
  }
  
  private var messageFont: SwiftUI.Font {
    guard (message.role == .user || message.role == .assistant) else {
      return .system(size: fontSize, weight: colorScheme == .dark ? .ultraLight : .light, design: .monospaced)
    }
    return SwiftUI.Font.system(.body)
  }
}
