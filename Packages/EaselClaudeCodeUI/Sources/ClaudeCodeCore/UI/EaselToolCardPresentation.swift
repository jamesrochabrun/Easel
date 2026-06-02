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
  /// Human-readable, always specific headline for the activity (e.g. `Reading Button.swift`).
  let title: String
  /// Optional secondary detail (e.g. `42 lines`, the actual command). Never repeats the status.
  let subtitle: String?
  let status: EaselToolCardStatus
  let preview: String?
  let localhostURL: URL?
  let statusLabel: String
  let statusSystemImageName: String
  let accessibilityLabel: String

  @MainActor
  init(toolUse: ChatMessage, toolResult: ChatMessage?) {
    let toolName = toolUse.toolName ?? toolResult?.toolName ?? "Tool"
    let status = Self.status(for: toolUse, toolResult: toolResult)
    let resultContent = toolResult?.content ?? (toolUse.messageType == .toolResult ? toolUse.content : "")
    let url = Self.localhostURL(in: resultContent)
    let title = Self.title(for: toolUse, toolName: toolName)
    let subtitle = Self.subtitle(
      toolName: toolName,
      resultContent: resultContent,
      toolInputData: toolUse.toolInputData
    )

    self.title = title
    self.subtitle = subtitle
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
    let detail = subtitle.map { ", \($0)" } ?? ""
    self.accessibilityLabel = "\(title)\(detail), \(status.label)"
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

  // MARK: - Title

  private static func title(for message: ChatMessage, toolName: String) -> String {
    let parameters = message.toolInputData?.parameters

    switch toolName {
    case "Bash":
      return bashTitle(for: parameters?["command"])

    case "Read":
      if let name = fileDisplayName(parameters?["file_path"]) {
        return "Reading \(name)"
      }
      return "Reading a file"

    case "Write":
      if let name = fileDisplayName(parameters?["file_path"]) {
        return "Creating \(name)"
      }
      return "Creating a file"

    case "Edit", "MultiEdit":
      if let name = fileDisplayName(parameters?["file_path"]) {
        return "Editing \(name)"
      }
      return "Editing a file"

    case "FileChange":
      if let name = fileDisplayName(parameters?["file_path"]) {
        return "Updating \(name)"
      }
      return "Updating files"

    case "Grep":
      if let pattern = nonEmpty(parameters?["pattern"]) {
        return "Searching for \"\(truncate(pattern, limit: 40))\""
      }
      return "Searching the project"

    case "Glob":
      if let pattern = nonEmpty(parameters?["pattern"]) {
        return globTitle(for: pattern)
      }
      return "Finding files"

    case "LS":
      if let name = fileDisplayName(parameters?["path"]) {
        return "Browsing \(name)"
      }
      return "Looking through files"

    case "WebSearch":
      if let query = nonEmpty(parameters?["query"]) {
        return "Searching the web for \"\(truncate(query, limit: 40))\""
      }
      return "Searching the web"

    case "WebFetch":
      if let host = host(from: parameters?["url"]) {
        return "Reading \(host)"
      }
      return "Reading web content"

    case "TodoWrite":
      return "Updating the plan"

    case "Task":
      return nonEmpty(parameters?["description"]) ?? "Working through a task"

    case "ExitPlanMode", "exit_plan_mode":
      return "Reviewing the plan"

    default:
      if let firstParameter = message.toolInputData?.keyParameters.first {
        return "\(friendlyToolName(toolName)) \(friendlyParameterValue(firstParameter.value))"
      }
      return friendlyToolName(toolName)
    }
  }

  // MARK: - Subtitle

  private static func subtitle(
    toolName: String,
    resultContent: String,
    toolInputData: ToolInputData?
  ) -> String? {
    let parameters = toolInputData?.parameters

    switch toolName {
    case "Read":
      let lines = resultContent.split(whereSeparator: \.isNewline).count
      guard lines > 0 else { return nil }
      return lines == 1 ? "1 line" : "\(lines) lines"

    case "FileChange":
      guard let count = fileChangeCount(in: resultContent) else { return nil }
      return count == 1 ? "1 file" : "\(count) files"

    case "Grep":
      if let include = nonEmpty(parameters?["include"]) {
        return "in \(include)"
      }
      if let name = fileDisplayName(parameters?["path"]) {
        return "in \(name)"
      }
      return nil

    default:
      return nil
    }
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
    let toolResultsByID = resultByToolUseID(in: messages)
    var index = messages.count - 1

    while index >= 0 {
      let message = messages[index]

      if message.messageType == .toolUse {
        if pairedResult(after: index, in: messages, resultByToolUseID: toolResultsByID) == nil {
          return title(for: message, toolName: message.toolName ?? "Tool")
        }
        return nil
      }

      index -= 1
    }

    return nil
  }

  private static func resultByToolUseID(in messages: [ChatMessage]) -> [String: ChatMessage] {
    var results: [String: ChatMessage] = [:]

    for message in messages where message.messageType == .toolResult ||
      message.messageType == .toolError ||
      message.messageType == .toolDenied {
      guard let toolUseID = message.toolUseID, !toolUseID.isEmpty else { continue }
      if results[toolUseID] == nil {
        results[toolUseID] = message
      }
    }

    return results
  }

  private static func pairedResult(
    after index: Int,
    in messages: [ChatMessage],
    resultByToolUseID: [String: ChatMessage]
  ) -> ChatMessage? {
    let toolUse = messages[index]

    if let toolUseID = toolUse.toolUseID, !toolUseID.isEmpty {
      return resultByToolUseID[toolUseID]
    }

    let nextIndex = index + 1
    guard nextIndex < messages.count else { return nil }

    let candidate = messages[nextIndex]
    guard candidate.messageType == .toolResult ||
      candidate.messageType == .toolError ||
      candidate.messageType == .toolDenied else {
      return nil
    }

    if candidate.toolUseID != nil {
      return nil
    }

    return candidate
  }

  // MARK: - Bash

  /// Derives a friendly, human-readable headline for a shell invocation — always a
  /// plain-language verb, never the raw command.
  ///
  /// A confident high-level intent when we recognise one (running tests, building, …);
  /// otherwise a verb derived from the command's main program plus the file or folder it
  /// touches. The raw command is intentionally never shown — only the action.
  private static func bashTitle(for command: String?) -> String {
    let cleaned = cleanedCommand(command)
    guard !cleaned.isEmpty else { return "Checking the project" }
    return semanticBashVerb(for: cleaned) ?? programActivity(for: cleaned)
  }

  /// Recognises confident, high-level intents that read better than a per-program verb.
  private static func semanticBashVerb(for command: String) -> String? {
    let lowercased = command.lowercased()

    if containsAny(lowercased, [
      "npm install", "pnpm install", "yarn install", "bun install",
      "npm add", "pnpm add", "yarn add", "bun add",
      "pod install", "bundle install"
    ]) {
      return "Installing packages"
    }

    if containsAny(lowercased, [
      "npm run dev", "pnpm dev", "yarn dev", "bun dev",
      "vite", "next dev", "astro dev", "serve", "http.server"
    ]) {
      return "Starting the preview"
    }

    if lowercased.contains("xcodebuild") && lowercased.contains(" test") {
      return "Running tests"
    }

    if containsAny(lowercased, [
      "swift test", "xcodebuild test", "npm test", "npm run test",
      "pnpm test", "yarn test", "bun test", "pytest", "vitest", "jest"
    ]) {
      return "Running tests"
    }

    if containsAny(lowercased, [
      "swift build", "xcodebuild", "npm run build", "pnpm build",
      "yarn build", "bun run build", "cargo build", "go build"
    ]) {
      return "Building the project"
    }

    // Match lint/format as whole tokens so words like "information" do not trip it.
    if tokenize(lowercased).contains(where: { token in
      ["lint", "format", "swiftformat", "swiftlint", "prettier", "eslint", "biome"].contains(token)
        || token.hasSuffix("lint")
    }) {
      return "Formatting code"
    }

    return nil
  }

  /// Friendly verb derived from the command's main program and the file/folder argument.
  private static func programActivity(for command: String) -> String {
    let tokens = tokenize(primarySegment(of: command))
    guard let rawProgram = tokens.first else { return "Checking the project" }
    let program = lastPathComponent(rawProgram)
    let object = fileArgument(in: tokens)

    switch program {
    case "ls", "tree", "exa", "lsd", "dir":
      return "Looking through files"
    case "cat", "bat", "less", "more", "head", "tail", "sed", "awk", "nl":
      return object.map { "Reading \($0)" } ?? "Reading a file"
    case "rg", "grep", "egrep", "fgrep", "ag", "ack", "ripgrep":
      return "Searching files"
    case "find", "fd":
      return object.map { "Looking through \($0)" } ?? "Looking through files"
    case "mkdir":
      return "Creating a folder"
    case "touch":
      return object.map { "Creating \($0)" } ?? "Creating a file"
    case "cp", "rsync", "scp":
      return "Copying files"
    case "mv":
      return "Moving files"
    case "rm", "rmdir", "trash", "unlink":
      return "Removing files"
    case "chmod", "chown", "xattr":
      return "Updating file permissions"
    case "curl", "wget", "http", "https":
      return isLocalhostPreviewCommand(tokens) ? "Checking for updates" : "Fetching from the web"
    case "open":
      return object.map { "Opening \($0)" } ?? "Opening a file"
    case "git":
      return gitActivity(for: tokens)
    case "echo", "printf", "pwd", "whoami", "date", "which", "type", "env", "uname":
      return "Checking the project"
    case "node", "deno", "bun", "python", "python3", "ruby", "go", "cargo", "php", "java", "make", "swift":
      return object.map { "Running \($0)" } ?? "Running \(program)"
    default:
      return "Running \(program)"
    }
  }

  private static func gitActivity(for tokens: [String]) -> String {
    let subcommand = tokens.dropFirst().first { !$0.hasPrefix("-") }?.lowercased()
    switch subcommand {
    case "status", "log", "diff", "show", "branch", "blame", "describe":
      return "Checking project history"
    case "add", "commit", "restore", "reset", "stash", "rm":
      return "Saving project changes"
    case "push", "pull", "fetch", "clone":
      return "Syncing with the remote"
    case "checkout", "switch":
      return "Switching branches"
    default:
      return "Working with Git"
    }
  }

  /// First meaningful command in a `&&`/`;` chain, skipping trivial navigation like `cd`/`pwd`.
  private static func primarySegment(of command: String) -> String {
    var segments = [command]
    for separator in ["&&", "||", ";"] {
      segments = segments.flatMap { $0.components(separatedBy: separator) }
    }
    let trimmed = segments
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }

    let trivial: Set<String> = ["cd", "pwd", "clear", "export", "set", "unset", "source", "."]
    for segment in trimmed {
      let program = tokenize(segment).first ?? ""
      if !trivial.contains(program), !program.contains("=") {
        return segment
      }
    }
    return trimmed.first ?? command
  }

  private static func tokenize(_ value: String) -> [String] {
    value.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
  }

  /// First argument that looks like a file or folder (ignores flags and quoted ranges).
  private static func fileArgument(in tokens: [String]) -> String? {
    for token in tokens.dropFirst() {
      guard !token.hasPrefix("-") else { continue }
      let unquoted = token.trimmingCharacters(in: CharacterSet(charactersIn: "'\"`"))
      guard !unquoted.isEmpty, looksLikePath(unquoted) else { continue }
      return fileDisplayName(unquoted)
    }
    return nil
  }

  private static func isLocalhostPreviewCommand(_ tokens: [String]) -> Bool {
    tokens.dropFirst().contains { token in
      let unquoted = token
        .trimmingCharacters(in: CharacterSet(charactersIn: "'\"`"))
        .lowercased()
      return unquoted.contains("http://localhost:")
        || unquoted.contains("https://localhost:")
        || unquoted.contains("http://127.0.0.1:")
        || unquoted.contains("https://127.0.0.1:")
        || unquoted.contains("http://[::1]:")
        || unquoted.contains("https://[::1]:")
    }
  }

  private static func looksLikePath(_ value: String) -> Bool {
    if value.contains("/") { return true }
    if let dotIndex = value.lastIndex(of: "."), dotIndex != value.startIndex {
      let ext = value[value.index(after: dotIndex)...]
      if !ext.isEmpty, ext.allSatisfy({ $0.isLetter || $0.isNumber }) { return true }
    }
    return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
  }

  private static func lastPathComponent(_ value: String) -> String {
    guard value.contains("/") else { return value }
    let component = URL(fileURLWithPath: value).lastPathComponent
    return component.isEmpty ? value : component
  }

  /// Strips a leading `cd <path> &&` / `cd <path>;` and collapses whitespace so the
  /// command reads as a single tidy line.
  private static func cleanedCommand(_ raw: String?) -> String {
    guard var command = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
      return ""
    }

    if command.hasPrefix("cd ") {
      if let separator = command.range(of: "&&") ?? command.range(of: ";") {
        command = String(command[separator.upperBound...])
      }
    }

    let collapsed = command
      .split(whereSeparator: { $0.isNewline || $0 == "\t" })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return collapsed.trimmingCharacters(in: .whitespaces)
  }

  // MARK: - Helpers

  private static func fileChangeCount(in content: String) -> Int? {
    let words = content.split(separator: " ")
    guard let changedIndex = words.firstIndex(where: { $0.lowercased() == "changed" }) else {
      return nil
    }

    let nextIndex = words.index(after: changedIndex)
    guard nextIndex < words.endIndex else { return nil }
    return Int(words[nextIndex])
  }

  /// Friendly title for a glob pattern, e.g. `**/*.swift` -> `Finding Swift files`.
  private static func globTitle(for pattern: String) -> String {
    if let ext = globExtension(in: pattern) {
      return "Finding \(ext) files"
    }
    return "Finding files matching \(truncate(pattern, limit: 32))"
  }

  private static func globExtension(in pattern: String) -> String? {
    guard let lastDot = pattern.lastIndex(of: ".") else { return nil }
    let raw = pattern[pattern.index(after: lastDot)...]
    let ext = raw.prefix { $0.isLetter || $0.isNumber }
    guard !ext.isEmpty, ext.count <= 5 else { return nil }
    return displayName(forExtension: String(ext))
  }

  private static func displayName(forExtension ext: String) -> String {
    switch ext.lowercased() {
    case "swift": return "Swift"
    case "ts", "tsx": return "TypeScript"
    case "js", "jsx", "mjs": return "JavaScript"
    case "py": return "Python"
    case "rb": return "Ruby"
    case "go": return "Go"
    case "rs": return "Rust"
    case "java": return "Java"
    case "kt", "kts": return "Kotlin"
    case "md": return "Markdown"
    case "json": return "JSON"
    case "yml", "yaml": return "YAML"
    default: return ".\(ext.lowercased())"
    }
  }

  private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
    needles.contains { value.contains($0) }
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return value
  }

  /// Last path component for a file path parameter, ignoring empty values.
  private static func fileDisplayName(_ path: String?) -> String? {
    guard let path = nonEmpty(path) else { return nil }
    if let skillName = skillName(forManifestPath: path) {
      return "\(skillName) skill"
    }
    let component = URL(fileURLWithPath: path).lastPathComponent
    return component.isEmpty ? nil : component
  }

  private static func skillName(forManifestPath path: String) -> String? {
    let url = URL(fileURLWithPath: path)
    guard url.lastPathComponent.caseInsensitiveCompare("SKILL.md") == .orderedSame else {
      return nil
    }

    let skillName = url.deletingLastPathComponent().lastPathComponent
    guard !skillName.isEmpty, skillName != "." else { return nil }
    return skillName
  }

  private static func host(from urlString: String?) -> String? {
    guard let urlString = nonEmpty(urlString),
          let host = URL(string: urlString)?.host else { return nil }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
  }

  private static func truncate(_ value: String, limit: Int) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > limit else { return trimmed }
    let endIndex = trimmed.index(trimmed.startIndex, offsetBy: limit)
    return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespaces) + "…"
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
