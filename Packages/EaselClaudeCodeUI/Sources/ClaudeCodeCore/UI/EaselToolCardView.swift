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
  @State private var isExpanded: Bool
  @Environment(AppearanceSettings.self) private var appearanceSettings
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

    // Default collapsed, but expand for tools that need immediate visibility
    let toolName = toolUse.toolName ?? ""
    let needsExpanded = ["TodoWrite", "ExitPlanMode", "exit_plan_mode"].contains(toolName)
    let persisted = viewModel.messageExpansionStates[toolUse.id]
    _isExpanded = State(initialValue: persisted ?? needsExpanded)
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
    VStack(alignment: .leading, spacing: EaselChatRuntimeStyle.Spacing.cardContentSpacing) {
      header

      if isExpanded {
        if shouldShowDetailedContent {
          detailedContent
        } else if let preview = presentation.preview {
          previewBlock(preview)
        }
      }
    }
    .padding(isExpanded ? EaselChatRuntimeStyle.Spacing.cardPadding : EaselChatRuntimeStyle.Spacing.cardPaddingCompact)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselChatRuntimeStyle.cardBackground(for: colorScheme, themeColors: appearanceSettings.themeColors), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
    .overlay {
      RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius)
        .stroke(EaselChatRuntimeStyle.border(for: colorScheme, themeColors: appearanceSettings.themeColors), lineWidth: 1)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
        isExpanded.toggle()
        viewModel.messageExpansionStates[toolUse.id] = isExpanded
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: EaselChatRuntimeStyle.Spacing.headerDotSpacing) {
      Circle()
        .fill(statusColor)
        .frame(width: EaselChatRuntimeStyle.Spacing.statusDotSize, height: EaselChatRuntimeStyle.Spacing.statusDotSize)

      VStack(alignment: .leading, spacing: 3) {
        Text(presentation.title)
          .font(EaselChatRuntimeStyle.Typography.primaryTitle)
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)

        Text(presentation.metadata)
          .font(EaselChatRuntimeStyle.Typography.secondaryBody)
          .foregroundStyle(statusColor)
      }

      Spacer(minLength: 12)

      HStack(spacing: 6) {
        Image(systemName: statusIcon)
          .font(EaselChatRuntimeStyle.Typography.statusIcon)
          .foregroundStyle(statusColor)

        if hasExpandableContent {
          Image(systemName: "chevron.right")
            .font(.system(size: EaselChatRuntimeStyle.Spacing.chevronSize, weight: .medium))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
      }
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
      .font(EaselChatRuntimeStyle.Typography.code(size: fontSize - 1))
      .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme, themeColors: appearanceSettings.themeColors))
      .textSelection(.enabled)
      .padding(EaselChatRuntimeStyle.Spacing.previewPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme, themeColors: appearanceSettings.themeColors), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius))
      .lineLimit(10)
  }

  private var presentation: EaselToolCardPresentation {
    EaselToolCardPresentation(toolUse: toolUse, toolResult: toolResult)
  }

  private var hasExpandableContent: Bool {
    shouldShowDetailedContent || presentation.preview != nil
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
