//
//  EaselDesignSystemProfile.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemProfile: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public let blurb: String
  public let notes: String
  public let sourceLinks: [String]
  public let workingDirectory: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    name: String,
    blurb: String,
    notes: String,
    sourceLinks: [String],
    workingDirectory: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.blurb = blurb
    self.notes = notes
    self.sourceLinks = sourceLinks
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public func creationPrompt() -> String {
    var lines: [String] = [
      "You are creating a reusable Codex Design design system in this folder.",
      "Design system name: \(name)",
      "Working directory: \(workingDirectory)",
      "Company/design-system brief: \(blurb)",
      "Inspect all relevant files under `resources/` before designing.",
      "Build a browsable design-system catalog in `index.html` and keep `npm run dev` working.",
      "Write `.easel/catalog.json` with this JSON shape: name, summary, generatedAt, componentGroups. Each component group must include id, title, summary, optional previewPath, and items.",
      "Create component groups for the product patterns you find: foundations, typography, color, buttons, inputs, navigation, cards, badges, layout, and any product-specific components.",
      "Use realistic examples and production-quality interaction states so future projects can inspect and reuse the system.",
    ]

    if !sourceLinks.isEmpty {
      lines.append("Reference links: \(sourceLinks.joined(separator: ", "))")
    }

    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines.append("Additional notes: \(notes.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    lines.append("Start by inspecting the scaffold and resources, then replace or extend the placeholder catalog.")
    return lines.joined(separator: "\n")
  }
}
