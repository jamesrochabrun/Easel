//
//  TweaksJobRequestFactory.swift
//  EaselWebInspector
//
//  Builds background-job requests for the tweaks popover's agent actions.
//  Returns nil when the preview URL can't be mapped into the project, in
//  which case callers fall back to the legacy chat-session path.
//

import Canvas
import EaselKit
import Foundation

// MARK: - TweaksJobRequestFactory

public enum TweaksJobRequestFactory {

  public enum TweaksJobInstruction: Equatable, Sendable {
    case ideas
    case custom(String)
  }

  public static func makeRequest(
    previewURL: URL,
    projectPath: String,
    instruction: TweaksJobInstruction
  ) -> BackgroundAgentJobRequest? {
    guard let absoluteTarget = TweaksDefaultsWriteCoordinator.resolveFilePath(
      previewURL: previewURL,
      projectPath: projectPath
    ) else {
      return nil
    }

    let normalizedProject = URL(fileURLWithPath: projectPath)
      .standardizedFileURL.resolvingSymlinksInPath().path
    let normalizedTarget = URL(fileURLWithPath: absoluteTarget)
      .standardizedFileURL.resolvingSymlinksInPath().path
    guard normalizedTarget.hasPrefix(normalizedProject + "/") else {
      return nil
    }

    let relativePath = String(normalizedTarget.dropFirst(normalizedProject.count + 1))
    let fileName = (relativePath as NSString).lastPathComponent

    let prompt: String
    let summary: String
    switch instruction {
    case .ideas:
      // The relative path (not just the file name) points the headless agent
      // straight at the file inside its shadow workspace.
      prompt = TweaksPromptBuilder.ideasPrompt(fileName: relativePath)
      summary = "Ideas"
    case .custom(let text):
      prompt = TweaksPromptBuilder.customPrompt(fileName: relativePath, instruction: text)
      summary = text
    }

    return BackgroundAgentJobRequest(
      kind: .tweaks,
      projectPath: normalizedProject,
      targetFileRelativePath: relativePath,
      displayFileName: fileName,
      prompt: prompt,
      summary: summary
    )
  }
}
