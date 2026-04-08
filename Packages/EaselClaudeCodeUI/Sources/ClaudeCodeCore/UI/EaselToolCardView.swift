import SwiftUI
import CCTerminalServiceInterface

struct EaselToolCardView: View {
  let toolUse: ChatMessage
  let toolResult: ChatMessage?
  let settingsStorage: SettingsStorage
  let terminalService: TerminalService
  let fontSize: Double
  let viewModel: ChatViewModel
  let showArtifact: ((Artifact) -> Void)?

  @State private var textFormatter: TextFormatter
  @Environment(\.colorScheme) private var colorScheme

  init(
    toolUse: ChatMessage,
    toolResult: ChatMessage?,
    settingsStorage: SettingsStorage,
    terminalService: TerminalService,
    fontSize: Double,
    viewModel: ChatViewModel,
    showArtifact: ((Artifact) -> Void)? = nil
  ) {
    self.toolUse = toolUse
    self.toolResult = toolResult
    self.settingsStorage = settingsStorage
    self.terminalService = terminalService
    self.fontSize = fontSize
    self.viewModel = viewModel
    self.showArtifact = showArtifact

    let projectRoot = settingsStorage.projectPath.isEmpty ? nil : URL(fileURLWithPath: settingsStorage.projectPath)
    _textFormatter = State(initialValue: TextFormatter(projectRoot: projectRoot))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      toolCard

      if let localhostURL = presentation.localhostURL {
        EaselDevServerStatusCard(url: localhostURL)
      }
    }
  }

  private var toolCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      header

      if shouldShowDetailedContent {
        detailedContent
      } else if let preview = presentation.preview {
        previewBlock(preview)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselChatRuntimeStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
    .overlay {
      RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius)
        .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 10) {
      Circle()
        .fill(statusColor)
        .frame(width: 6, height: 6)

      VStack(alignment: .leading, spacing: 3) {
        Text(presentation.title)
          .font(.callout.bold())
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)

        Text(presentation.metadata)
          .font(.caption)
          .foregroundStyle(statusColor)
      }

      Spacer(minLength: 12)

      Image(systemName: statusIcon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(statusColor)
    }
  }

  private var detailedContent: some View {
    MessageContentView(
      message: toolUse,
      textFormatter: textFormatter,
      fontSize: fontSize,
      horizontalPadding: 0,
      showArtifact: showArtifact,
      maxWidth: EaselChatRuntimeStyle.maxContentWidth,
      terminalService: terminalService,
      projectPath: settingsStorage.projectPath,
      onApprovalAction: {
        viewModel.messageExpansionStates[toolUse.id] = false
      },
      viewModel: viewModel
    )
  }

  private func previewBlock(_ preview: String) -> some View {
    Text(preview)
      .font(.system(size: fontSize - 1, design: .monospaced))
      .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
      .textSelection(.enabled)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius))
      .lineLimit(10)
  }

  private var presentation: EaselToolCardPresentation {
    EaselToolCardPresentation(toolUse: toolUse, toolResult: toolResult)
  }

  private var shouldShowDetailedContent: Bool {
    guard toolUse.messageType == .toolUse else { return false }
    guard let toolName = toolUse.toolName else { return false }
    return ["TodoWrite", "ExitPlanMode", "exit_plan_mode"].contains(toolName)
  }

  private var statusColor: Color {
    switch presentation.status {
    case .running:
      return EaselChatRuntimeStyle.running
    case .completed:
      return EaselChatRuntimeStyle.completed
    case .failed:
      return EaselChatRuntimeStyle.failed
    case .denied:
      return EaselChatRuntimeStyle.denied
    }
  }

  private var statusIcon: String {
    switch presentation.status {
    case .running:
      return "circle"
    case .completed:
      return "checkmark"
    case .failed:
      return "xmark"
    case .denied:
      return "minus"
    }
  }
}
