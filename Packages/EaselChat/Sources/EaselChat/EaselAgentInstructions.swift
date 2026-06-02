//
//  EaselAgentInstructions.swift
//  EaselChat
//

import Foundation

enum EaselAgentInstructions {
  static let systemPromptPrefix = """
    You are operating inside Codex Design. The app owns the embedded Canvas preview panel for localhost UI inspection and refresh.
    Prefer the embedded preview or browser MCP tools when they are available. Do not open external browser apps or use shell commands such as `open`, `open -a`, `xdg-open`, or `start` to preview project UI.
    Do not start a second preview server when a current embedded preview URL is available; reuse that URL and edit files in place.
    Write or copy every generated project asset into the project's resources/ folder before referencing it from app UI.
    Keep `npm run dev` working. When reporting a dev server URL, provide a clean root localhost URL with no Markdown, quotes, backticks, or trailing punctuation.
    """

  static func hiddenContext(projectPath: String?, previewURL: URL?) -> String {
    var lines = [
      "--- Codex Design Runtime Context ---",
      "The right-side Canvas panel is the preview surface for this session.",
      "Use embedded preview/browser MCP tools for localhost inspection, navigation, refresh, and screenshots when those tools are available.",
      "Do not launch an external browser app for previewing this project.",
      "Do not start a second preview server when the current embedded preview URL is available; reuse the existing preview and edit files in place.",
      "Write or copy every generated project asset into the project's resources/ folder before referencing it from app UI.",
      "Keep npm run dev functional for the project.",
      "If you start or mention a dev server, print only a clean root URL such as http://127.0.0.1:<port>/ or http://localhost:<port>/ with no Markdown, quotes, backticks, or trailing punctuation.",
      "After UI file edits, refresh the embedded preview when a preview-control tool is available.",
    ]

    if let projectPath, !projectPath.isEmpty {
      lines.append("Current project path: \(projectPath)")
    }

    if let previewURL {
      lines.append("Current embedded preview URL: \(previewURL.absoluteString)")
    }

    return lines.joined(separator: "\n")
  }

  static func appendingHiddenContext(_ hiddenContext: String?, projectPath: String?, previewURL: URL?) -> String {
    [hiddenContext, self.hiddenContext(projectPath: projectPath, previewURL: previewURL)]
      .compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
      }
      .joined(separator: "\n\n")
  }
}
