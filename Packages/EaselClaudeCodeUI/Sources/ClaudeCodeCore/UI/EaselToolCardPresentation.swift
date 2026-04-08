import Foundation

enum EaselToolCardStatus: Equatable {
  case running
  case completed
  case failed
  case denied

  var label: String {
    switch self {
    case .running:
      return "running"
    case .completed:
      return "completed"
    case .failed:
      return "failed"
    case .denied:
      return "denied"
    }
  }
}

struct EaselToolCardPresentation: Equatable {
  let title: String
  let metadata: String
  let status: EaselToolCardStatus
  let preview: String?
  let localhostURL: URL?

  @MainActor
  init(toolUse: ChatMessage, toolResult: ChatMessage?) {
    let toolName = toolUse.toolName ?? toolResult?.toolName ?? "Tool"
    let tool = ToolRegistry.shared.tool(for: toolName)
    let status = Self.status(for: toolUse, toolResult: toolResult)
    let resultContent = toolResult?.content ?? (toolUse.messageType == .toolResult ? toolUse.content : "")
    let url = Self.localhostURL(in: resultContent)

    self.title = Self.title(for: toolUse, toolName: toolName)
    self.metadata = Self.metadata(
      toolName: toolName,
      tool: tool,
      status: status,
      resultContent: resultContent
    )
    self.status = status
    self.preview = Self.preview(for: toolName, resultContent: resultContent, localhostURL: url)
    self.localhostURL = url
  }

  private static func status(for toolUse: ChatMessage, toolResult: ChatMessage?) -> EaselToolCardStatus {
    if let toolResult {
      switch toolResult.messageType {
      case .toolError:
        return .failed
      case .toolDenied:
        return .denied
      default:
        return toolResult.isError ? .failed : .completed
      }
    }

    switch toolUse.messageType {
    case .toolError:
      return .failed
    case .toolDenied:
      return .denied
    case .toolResult:
      return toolUse.isError ? .failed : .completed
    default:
      return .running
    }
  }

  private static func title(for message: ChatMessage, toolName: String) -> String {
    if toolName == "Bash", let command = message.toolInputData?.parameters["command"], !command.isEmpty {
      return command
    }

    if toolName == "Read", let path = message.toolInputData?.parameters["file_path"], !path.isEmpty {
      return "Read \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    if let firstParameter = message.toolInputData?.keyParameters.first {
      return "\(toolName) \(firstParameter.value)"
    }

    return toolName
  }

  private static func metadata(
    toolName: String,
    tool: ToolType?,
    status: EaselToolCardStatus,
    resultContent: String
  ) -> String {
    let category: String
    if toolName == "Read" || toolName == "Write" {
      category = "File"
    } else {
      category = tool?.friendlyName == nil ? toolName : toolName
    }

    if toolName == "Read" && !resultContent.isEmpty {
      let lines = resultContent.split(whereSeparator: \.isNewline).count
      if lines > 0 {
        return "\(category) - \(lines) lines"
      }
    }

    return "\(category) - \(status.label)"
  }

  private static func preview(for toolName: String, resultContent: String, localhostURL: URL?) -> String? {
    guard localhostURL == nil else { return nil }
    let trimmed = resultContent.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let shouldPreview = ["Read", "Write", "Bash", "WebFetch", "WebSearch"].contains(toolName)
    guard shouldPreview else { return nil }

    return trimmed
      .split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(8)
      .joined(separator: "\n")
  }

  static func localhostURL(in content: String) -> URL? {
    let pattern = #"https?://(?:localhost|127\.0\.0\.1):\d{1,5}(?:/[^\s\)\]\}\"'*<>]*)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(content.startIndex..<content.endIndex, in: content)
    guard let match = regex.matches(in: content, range: range).last,
          let matchRange = Range(match.range, in: content) else {
      return nil
    }
    return URL(string: String(content[matchRange]))
  }
}
