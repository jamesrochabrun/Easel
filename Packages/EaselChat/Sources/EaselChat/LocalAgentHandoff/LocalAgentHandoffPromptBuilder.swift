//
//  LocalAgentHandoffPromptBuilder.swift
//  EaselChat
//

import Foundation
import EaselSlides

enum LocalAgentHandoffPromptBuilder {
  static let defaultDetails = "the designs in this project"

  static func prompt(details: String, context: LocalAgentHandoffContext) -> String {
    let implementationDetails = normalizedDetails(details)
    let handoffContext = handoffContext(for: context)

    return """
    You are receiving a local Easel handoff. Implement in the current terminal working directory.

    Easel resources path: \(context.easelProjectPath)

    Before changing files:
    - Read `\(context.easelProjectPath)/README.md`.
    - Inspect `\(context.easelProjectPath)/resources/` for project assets and design inputs.
    - If `\(context.easelProjectPath)/resources/design-system/DESIGN.md` exists, read it and build directly from its colors, type, spacing, radii, effects, and component families.
    - Treat the Easel resources path as read-only source material unless the user explicitly asks you to update it.

    \(handoffContext)

    Implement: \(implementationDetails)
    """
  }

  private static func handoffContext(for context: LocalAgentHandoffContext) -> String {
    var lines = [
      "--- Easel Handoff Context ---",
      "Easel resources path: \(context.easelProjectPath)",
    ]

    if let project = context.project {
      lines.append("Current project type: \(project.kind.displayName)")

      if project.kind == .slideDeck {
        lines.append("Slide deck contract: \(SlideDeckContract.authoringSummary)")
      }

      if project.kind == .prototype {
        lines.append("Current prototype fidelity: \(project.fidelity.displayName)")
        lines.append("Prototype fidelity contract: \(project.fidelity.agentGuidance)")
      }

      if project.designSystem.kind == .custom {
        lines.append("Active design system: \(project.designSystem.displayName). Its spec is at \(context.easelProjectPath)/resources/design-system/DESIGN.md.")
      }
    }

    if let previewURL = context.previewURL {
      lines.append("Easel preview URL: \(previewURL.absoluteString)")
    }

    return lines.joined(separator: "\n")
  }

  private static func normalizedDetails(_ details: String) -> String {
    let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? defaultDetails : trimmed
  }
}
