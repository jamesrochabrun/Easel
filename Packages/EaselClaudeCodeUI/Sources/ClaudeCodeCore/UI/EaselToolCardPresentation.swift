import Foundation

enum EaselToolCardStatus: Equatable {
  case running
  case completed
  case failed
  case denied

  var label: String {
    switch self {
    case .running:
      return "Working"
    case .completed:
      return "Done"
    case .failed:
      return "Needs attention"
    case .denied:
      return "Not run"
    }
  }

  var systemImageName: String {
    switch self {
    case .running:
      return "hourglass"
    case .completed:
      return "checkmark.circle.fill"
    case .failed:
      return "exclamationmark.triangle.fill"
    case .denied:
      return "hand.raised.fill"
    }
  }
}

struct EaselToolCardPresentation: Equatable {
  let title: String
  let metadata: String
  let status: EaselToolCardStatus
  let preview: String?
  let localhostURL: URL?
  let statusLabel: String
  let statusSystemImageName: String
  let accessibilityLabel: String

  @MainActor
  init(toolUse: ChatMessage, toolResult: ChatMessage?) {
    let toolName = toolUse.toolName ?? toolResult?.toolName ?? "Tool"
    let tool = ToolRegistry().tool(for: toolName)
    let status = Self.status(for: toolUse, toolResult: toolResult)
    let resultContent = toolResult?.content ?? (toolUse.messageType == .toolResult ? toolUse.content : "")
    let url = Self.localhostURL(in: resultContent)
    let title = Self.title(for: toolUse, toolName: toolName)
    let metadata = Self.metadata(
      toolName: toolName,
      tool: tool,
      status: status,
      resultContent: resultContent,
      toolInputData: toolUse.toolInputData
    )

    self.title = title
    self.metadata = metadata
    self.status = status
    self.preview = Self.preview(
      for: toolName,
      resultContent: resultContent,
      toolInputData: toolUse.toolInputData,
      localhostURL: url
    )
    self.localhostURL = url
    self.statusLabel = status.label
    self.statusSystemImageName = status.systemImageName
    self.accessibilityLabel = "\(title), \(metadata), \(status.label)"
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
    if toolName == "Bash" {
      return commandActivity(for: message.toolInputData?.parameters["command"]).title
    }

    if toolName == "Read", let path = message.toolInputData?.parameters["file_path"], !path.isEmpty {
      return "Reading \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    if ["Write", "Edit", "MultiEdit", "FileChange"].contains(toolName),
       let path = message.toolInputData?.parameters["file_path"],
       !path.isEmpty {
      return "Updating \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    if ["Glob", "Grep"].contains(toolName) {
      return "Searching project"
    }

    if toolName == "LS" {
      return "Looking through files"
    }

    if toolName == "WebSearch" {
      return "Searching the web"
    }

    if toolName == "WebFetch" {
      return "Reading web content"
    }

    if toolName == "TodoWrite" {
      return "Updating task list"
    }

    if toolName == "Task" {
      return message.toolInputData?.parameters["description"] ?? "Working through a task"
    }

    if toolName == "ExitPlanMode" || toolName == "exit_plan_mode" {
      return "Reviewing the plan"
    }

    if let firstParameter = message.toolInputData?.keyParameters.first {
      return "\(friendlyToolName(toolName)) \(friendlyParameterValue(firstParameter.value))"
    }

    return friendlyToolName(toolName)
  }

  private static func metadata(
    toolName: String,
    tool: ToolType?,
    status: EaselToolCardStatus,
    resultContent: String,
    toolInputData: ToolInputData?
  ) -> String {
    let category = category(for: toolName, tool: tool, toolInputData: toolInputData)

    if toolName == "Read" && !resultContent.isEmpty {
      let lines = resultContent.split(whereSeparator: \.isNewline).count
      if lines > 0 {
        return "\(category) - \(lines) lines - \(status.label)"
      }
    }

    if toolName == "FileChange", !resultContent.isEmpty {
      if let count = fileChangeCount(in: resultContent) {
        return "\(category) - \(count) files - \(status.label)"
      }
      return "\(category) - \(status.label)"
    }

    return "\(category) - \(status.label)"
  }

  private static func preview(
    for toolName: String,
    resultContent: String,
    toolInputData: ToolInputData?,
    localhostURL: URL?
  ) -> String? {
    guard localhostURL == nil else { return nil }
    let shouldPreview = ["TodoWrite", "ExitPlanMode", "exit_plan_mode", "WebSearch"].contains(toolName)
    guard shouldPreview else { return nil }

    let content = preferredPreviewContent(
      for: toolName,
      resultContent: resultContent,
      toolInputData: toolInputData
    )
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    return trimmed
      .split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(8)
      .joined(separator: "\n")
  }

  private static func preferredPreviewContent(
    for toolName: String,
    resultContent: String,
    toolInputData: ToolInputData?
  ) -> String {
    let trimmedResult = resultContent.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedResult.isEmpty {
      return trimmedResult
    }

    let rawParameters = toolInputData?.rawParameters
    let parameters = toolInputData?.parameters

    switch toolName {
    case "Write":
      return rawParameters?["content"] ?? parameters?["content"] ?? ""
    case "Edit":
      return rawParameters?["new_string"] ?? parameters?["new_string"] ?? ""
    case "MultiEdit":
      return rawParameters?["edits"] ?? parameters?["edits"] ?? ""
    case "TodoWrite":
      return parameters?["todos"] ?? ""
    default:
      return ""
    }
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

  static func activeActivityTitle(in messages: [ChatMessage]) -> String? {
    var index = messages.count - 1

    while index >= 0 {
      let message = messages[index]

      if message.messageType == .toolUse {
        if pairedResult(after: index, in: messages) == nil {
          return title(for: message, toolName: message.toolName ?? "Tool")
        }
        return nil
      }

      index -= 1
    }

    return nil
  }

  private static func pairedResult(after index: Int, in messages: [ChatMessage]) -> ChatMessage? {
    let nextIndex = index + 1
    guard nextIndex < messages.count else { return nil }

    let candidate = messages[nextIndex]
    guard candidate.messageType == .toolResult ||
      candidate.messageType == .toolError ||
      candidate.messageType == .toolDenied else {
      return nil
    }

    return candidate
  }

  private static func category(
    for toolName: String,
    tool: ToolType?,
    toolInputData: ToolInputData?
  ) -> String {
    switch toolName {
    case "Bash":
      return commandActivity(for: toolInputData?.parameters["command"]).category
    case "Read":
      return "File review"
    case "Write", "Edit", "MultiEdit", "FileChange":
      return "File update"
    case "Glob", "Grep", "LS":
      return "Project search"
    case "TodoWrite":
      return "Planning"
    case "WebFetch", "WebSearch":
      return "Web"
    case "Task":
      return "Task"
    case "ExitPlanMode", "exit_plan_mode":
      return "Plan"
    default:
      return tool?.friendlyName ?? friendlyToolName(toolName)
    }
  }

  private static func fileChangeCount(in content: String) -> Int? {
    let words = content.split(separator: " ")
    guard let changedIndex = words.firstIndex(where: { $0.lowercased() == "changed" }) else {
      return nil
    }

    let nextIndex = words.index(after: changedIndex)
    guard nextIndex < words.endIndex else { return nil }
    return Int(words[nextIndex])
  }

  private static func commandActivity(for command: String?) -> (title: String, category: String) {
    let command = command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let lowercased = command.lowercased()

    guard !lowercased.isEmpty else {
      return ("Working on the project", "Project task")
    }

    if containsAny(lowercased, [
      "npm install", "pnpm install", "yarn install", "bun install",
      "npm add", "pnpm add", "yarn add", "bun add",
      "pod install", "bundle install"
    ]) {
      return ("Installing project packages", "Setup")
    }

    if containsAny(lowercased, [
      "npm run dev", "pnpm dev", "yarn dev", "bun dev",
      "vite", "next dev", "astro dev", "serve", "python -m http.server"
    ]) {
      return ("Starting preview", "Preview")
    }

    if lowercased.contains("xcodebuild") && lowercased.contains(" test") {
      return ("Checking tests", "Quality check")
    }

    if containsAny(lowercased, [
      "swift test", "xcodebuild test", "npm test", "npm run test",
      "pnpm test", "yarn test", "bun test", "pytest", "vitest", "jest"
    ]) {
      return ("Checking tests", "Quality check")
    }

    if containsAny(lowercased, [
      "swift build", "xcodebuild", "npm run build", "pnpm build",
      "yarn build", "bun run build", "cargo build", "go build"
    ]) {
      return ("Building project", "Build")
    }

    if containsAny(lowercased, ["lint", "format", "swiftformat", "swiftlint", "prettier"]) {
      return ("Checking formatting", "Quality check")
    }

    if lowercased.contains("git ") || lowercased.hasPrefix("git") {
      return ("Checking project history", "Version history")
    }

    if commandStarts(lowercased, prefixes: [
      "rg", "grep", "find", "ls", "cat", "sed", "awk", "pwd", "wc", "head", "tail"
    ]) {
      return ("Looking through the project", "Project search")
    }

    if commandStarts(lowercased, prefixes: ["mkdir", "cp", "mv", "rm", "touch", "chmod"]) {
      return ("Organizing project files", "File update")
    }

    if containsAny(lowercased, ["npm run", "pnpm run", "yarn run", "bun run", "make "]) {
      return ("Running project task", "Project task")
    }

    return ("Working on the project", "Project task")
  }

  private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
    needles.contains { value.contains($0) }
  }

  private static func commandStarts(_ value: String, prefixes: [String]) -> Bool {
    prefixes.contains { prefix in
      value == prefix ||
        value.hasPrefix("\(prefix) ") ||
        value.hasPrefix("\(prefix)\n") ||
        value.contains("&& \(prefix) ") ||
        value.contains("; \(prefix) ") ||
        value.contains("| \(prefix) ")
    }
  }

  private static func friendlyToolName(_ toolName: String) -> String {
    toolName
      .replacingOccurrences(of: "mcp__", with: "")
      .replacingOccurrences(of: "__", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .capitalized
  }

  private static func friendlyParameterValue(_ value: String) -> String {
    guard value.contains("/") else { return value }
    return URL(fileURLWithPath: value).lastPathComponent
  }
}
