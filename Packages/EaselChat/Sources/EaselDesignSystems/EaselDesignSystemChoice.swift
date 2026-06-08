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
    // Legacy projects stored the design system as a bare preset string. Map any
    // value — including removed presets like "airbnb"/"apple"/"material" — to a
    // known preset, defaulting to none, so older projects still decode.
    if let legacyValue = try? decoder.singleValueContainer().decode(String.self) {
      self = .preset(EaselDesignSystemPreset(rawValue: legacyValue) ?? .none)
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
}
