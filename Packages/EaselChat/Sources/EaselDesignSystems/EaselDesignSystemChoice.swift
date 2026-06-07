//
//  EaselDesignSystemChoice.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemChoice: Codable, Hashable, Identifiable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case preset
    case custom
  }

  public let kind: Kind
  public let referenceID: String
  public let displayName: String
  public let detail: String
  public let workingDirectory: String?
  public let notes: String?
  public let sourceLinks: [String]

  public var id: String {
    "\(kind.rawValue):\(referenceID)"
  }

  public var preset: EaselDesignSystemPreset? {
    guard kind == .preset else { return nil }
    return EaselDesignSystemPreset(rawValue: referenceID)
  }

  public var isNone: Bool {
    preset == EaselDesignSystemPreset.none
  }

  public static func preset(_ preset: EaselDesignSystemPreset) -> EaselDesignSystemChoice {
    EaselDesignSystemChoice(
      kind: .preset,
      referenceID: preset.rawValue,
      displayName: preset.displayName,
      detail: preset.detail,
      workingDirectory: nil,
      notes: nil,
      sourceLinks: []
    )
  }

  public static func custom(_ profile: EaselDesignSystemProfile) -> EaselDesignSystemChoice {
    EaselDesignSystemChoice(
      kind: .custom,
      referenceID: profile.id.uuidString,
      displayName: profile.name,
      detail: profile.blurb,
      workingDirectory: profile.workingDirectory,
      notes: profile.notes,
      sourceLinks: profile.sourceLinks
    )
  }

  public init(
    kind: Kind,
    referenceID: String,
    displayName: String,
    detail: String,
    workingDirectory: String?,
    notes: String?,
    sourceLinks: [String]
  ) {
    self.kind = kind
    self.referenceID = referenceID
    self.displayName = displayName
    self.detail = detail
    self.workingDirectory = workingDirectory
    self.notes = notes
    self.sourceLinks = sourceLinks
  }

  public init(from decoder: Decoder) throws {
    if let legacyPreset = try? decoder.singleValueContainer().decode(EaselDesignSystemPreset.self) {
      self = .preset(legacyPreset)
      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    kind = try container.decode(Kind.self, forKey: .kind)
    referenceID = try container.decode(String.self, forKey: .referenceID)
    displayName = try container.decode(String.self, forKey: .displayName)
    detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
    workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    sourceLinks = try container.decodeIfPresent([String].self, forKey: .sourceLinks) ?? []
  }

  /// Folder name (under a project's `resources/design-systems/`) where this
  /// custom design system's files are copied so the agent can read them locally.
  /// Nil for presets, which have no local files (their tokens are described in
  /// the prompt instead).
  public var resourceFolderName: String? {
    guard kind == .custom else { return nil }
    let slug = Self.slug(displayName)
    return slug.isEmpty ? referenceID.lowercased() : slug
  }

  static func slug(_ value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let allowed = CharacterSet.alphanumerics
    var result = ""
    var previousWasSeparator = false

    for scalar in folded.unicodeScalars {
      if allowed.contains(scalar) {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if !previousWasSeparator {
        result.append("-")
        previousWasSeparator = true
      }
    }

    return result.trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
  }

  public static func normalizedPrecedence(_ choices: [EaselDesignSystemChoice]) -> [EaselDesignSystemChoice] {
    var result: [EaselDesignSystemChoice] = []
    var seenIDs: Set<String> = []

    for choice in choices where !seenIDs.contains(choice.id) {
      result.append(choice)
      seenIDs.insert(choice.id)
    }

    if result.contains(where: { !$0.isNone }) {
      result.removeAll { $0.isNone }
    }

    return result.isEmpty ? [.preset(.none)] : result
  }
}
