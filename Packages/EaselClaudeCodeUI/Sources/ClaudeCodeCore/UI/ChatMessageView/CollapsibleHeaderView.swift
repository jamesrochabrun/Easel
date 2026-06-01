import SwiftUI

struct CollapsibleHeaderView: View {
  
  let messageType: MessageType
  let toolName: String?
  let toolInputData: ToolInputData?
  let isExpanded: Binding<Bool>
  let fontSize: Double
  
  private let toolRegistry = ToolRegistry()
  private let formatter = ToolDisplayFormatter()
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    HStack(spacing: EaselChatRuntimeStyle.Spacing.headerDotSpacing) {
      // Tool icon
      Image(systemName: toolIcon)
        .font(EaselChatRuntimeStyle.Typography.toolIcon)
        .foregroundStyle(statusColor)
        .frame(width: 20, height: 20)

      // Message type label
      Text(headerText)
        .font(EaselChatRuntimeStyle.Typography.code(size: fontSize - 1))
        .foregroundStyle(.primary)

      Spacer()

      // Expand/collapse chevron
      Image(systemName: "chevron.right")
        .font(.system(size: EaselChatRuntimeStyle.Spacing.chevronSize, weight: .medium))
        .foregroundStyle(.secondary)
        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 5, style: .continuous)
        .fill(EaselChatRuntimeStyle.cardBackground(for: colorScheme))
        .overlay(
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
        )
    )
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isExpanded.wrappedValue.toggle()
      }
    }
  }
  
  private var headerText: String {
    switch messageType {
    case .toolUse:
      if let toolName = toolName {
        // Use the formatter to create a proper header
        let header = formatter.toolRequestHeader(toolName: toolName, toolInputData: toolInputData)
        return header.formattedContent
      }
      return "Tool Use"
      
    case .toolResult:
      if let toolName = toolName {
        let tool = toolRegistry.tool(for: toolName)
        return "\(tool?.friendlyName ?? toolName) completed"
      }
      return "Processing result"
      
    case .toolError:
      if let toolName = toolName {
        let tool = toolRegistry.tool(for: toolName)
        return "\(tool?.friendlyName ?? toolName) failed"
      }
      return "Error occurred"
      
    case .toolDenied:
      if let toolName = toolName {
        let tool = toolRegistry.tool(for: toolName)
        return "\(tool?.friendlyName ?? toolName) denied"
      }
      return "Edit denied by user"
      
    case .thinking:
      return "Thinking..."
      
    case .webSearch:
      return "Searching the web"
      
    default:
      return "Processing"
    }
  }
  
  private var toolIcon: String {
    if let toolName = toolName {
      let tool = toolRegistry.tool(for: toolName)
      return tool?.icon ?? "hammer"
    }
    
    switch messageType {
    case .thinking:
      return "brain"
    case .webSearch:
      return "globe"
    case .toolError:
      return "exclamationmark.triangle"
    case .toolDenied:
      return "xmark.circle"
    default:
      return isExpanded.wrappedValue ? "checkmark.circle.fill" : "checkmark.circle"
    }
  }
  
  private var statusColor: SwiftUI.Color {
    switch messageType {
    case .toolUse, .thinking, .webSearch:
      return EaselChatRuntimeStyle.running
    case .toolResult:
      return EaselChatRuntimeStyle.completedForeground(for: colorScheme)
    case .toolError:
      return .red
    case .toolDenied:
      return .secondary
    default:
      return .secondary
    }
  }
}
