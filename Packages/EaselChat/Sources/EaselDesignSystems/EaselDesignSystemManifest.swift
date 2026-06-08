//
//  EaselDesignSystemManifest.swift
//  EaselChat
//

import Foundation

public struct EaselDesignSystemManifest: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let name: String
  public let summary: String
  public let generatedAt: Date
  public let importMode: EaselDesignSystemFigImportMode
  public let sources: [EaselDesignSystemManifestSource]
  public let tokens: EaselDesignSystemTokenSet
  public let components: [EaselDesignSystemManifestComponent]
  public let references: [EaselDesignSystemManifestReference]

  public init(
    schemaVersion: Int = Self.currentSchemaVersion,
    name: String,
    summary: String,
    generatedAt: Date,
    importMode: EaselDesignSystemFigImportMode,
    sources: [EaselDesignSystemManifestSource],
    tokens: EaselDesignSystemTokenSet,
    components: [EaselDesignSystemManifestComponent],
    references: [EaselDesignSystemManifestReference]
  ) {
    self.schemaVersion = schemaVersion
    self.name = name
    self.summary = summary
    self.generatedAt = generatedAt
    self.importMode = importMode
    self.sources = sources
    self.tokens = tokens
    self.components = components
    self.references = references
  }
}

public struct EaselDesignSystemManifestSource: Codable, Equatable, Sendable {
  public let fileName: String
  public let relativePath: String
  public let sha256: String
  public let parserName: String?
  public let parserVersion: String?
  public let status: EaselDesignSystemManifestSourceStatus
  public let parsedAt: Date
  public let nodeCount: Int
  public let errorMessage: String?

  public init(
    fileName: String,
    relativePath: String,
    sha256: String,
    parserName: String?,
    parserVersion: String?,
    status: EaselDesignSystemManifestSourceStatus,
    parsedAt: Date,
    nodeCount: Int,
    errorMessage: String?
  ) {
    self.fileName = fileName
    self.relativePath = relativePath
    self.sha256 = sha256
    self.parserName = parserName
    self.parserVersion = parserVersion
    self.status = status
    self.parsedAt = parsedAt
    self.nodeCount = nodeCount
    self.errorMessage = errorMessage
  }
}

public enum EaselDesignSystemManifestSourceStatus: String, Codable, Sendable {
  case parsed
  case skipped
  case failed
}

public struct EaselDesignSystemTokenSet: Codable, Equatable, Sendable {
  public let colors: [EaselDesignSystemColorToken]
  public let typography: [EaselDesignSystemTypographyToken]
  public let spacing: [EaselDesignSystemNumberToken]
  public let radii: [EaselDesignSystemNumberToken]
  public let effects: [EaselDesignSystemEffectToken]

  public init(
    colors: [EaselDesignSystemColorToken],
    typography: [EaselDesignSystemTypographyToken],
    spacing: [EaselDesignSystemNumberToken],
    radii: [EaselDesignSystemNumberToken],
    effects: [EaselDesignSystemEffectToken]
  ) {
    self.colors = colors
    self.typography = typography
    self.spacing = spacing
    self.radii = radii
    self.effects = effects
  }

  public static let empty = EaselDesignSystemTokenSet(
    colors: [],
    typography: [],
    spacing: [],
    radii: [],
    effects: []
  )
}

public struct EaselDesignSystemColorToken: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let hex: String
  public let sourceNodeID: String?
  public let sourceNodeName: String?
  public let confidence: Double

  public init(
    id: String,
    name: String,
    hex: String,
    sourceNodeID: String?,
    sourceNodeName: String?,
    confidence: Double
  ) {
    self.id = id
    self.name = name
    self.hex = hex
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.confidence = confidence
  }
}

public struct EaselDesignSystemTypographyToken: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let fontFamily: String
  public let fontStyle: String?
  public let fontSize: Double?
  public let sourceNodeID: String?
  public let sourceNodeName: String?
  public let confidence: Double

  public init(
    id: String,
    name: String,
    fontFamily: String,
    fontStyle: String?,
    fontSize: Double?,
    sourceNodeID: String?,
    sourceNodeName: String?,
    confidence: Double
  ) {
    self.id = id
    self.name = name
    self.fontFamily = fontFamily
    self.fontStyle = fontStyle
    self.fontSize = fontSize
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.confidence = confidence
  }
}

public struct EaselDesignSystemNumberToken: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let value: Double
  public let unit: String
  public let sourceNodeID: String?
  public let sourceNodeName: String?
  public let confidence: Double

  public init(
    id: String,
    name: String,
    value: Double,
    unit: String,
    sourceNodeID: String?,
    sourceNodeName: String?,
    confidence: Double
  ) {
    self.id = id
    self.name = name
    self.value = value
    self.unit = unit
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.confidence = confidence
  }
}

public struct EaselDesignSystemEffectToken: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let kind: String
  public let sourceNodeID: String?
  public let sourceNodeName: String?
  public let confidence: Double

  public init(
    id: String,
    name: String,
    kind: String,
    sourceNodeID: String?,
    sourceNodeName: String?,
    confidence: Double
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.confidence = confidence
  }
}

public struct EaselDesignSystemManifestComponent: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let category: String
  public let sourceFileName: String
  public let sourceNodeID: String
  public let sourceNodeName: String
  public let sourcePageName: String?
  public let sourceNodeType: String
  public let childCount: Int
  public let variantCount: Int
  public let variantProperties: [EaselDesignSystemVariantProperty]
  public let confidence: Double

  public init(
    id: String,
    title: String,
    summary: String,
    category: String,
    sourceFileName: String,
    sourceNodeID: String,
    sourceNodeName: String,
    sourcePageName: String?,
    sourceNodeType: String,
    childCount: Int,
    variantCount: Int = 1,
    variantProperties: [EaselDesignSystemVariantProperty] = [],
    confidence: Double
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.category = category
    self.sourceFileName = sourceFileName
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.sourcePageName = sourcePageName
    self.sourceNodeType = sourceNodeType
    self.childCount = childCount
    self.variantCount = variantCount
    self.variantProperties = variantProperties
    self.confidence = confidence
  }
}

public struct EaselDesignSystemManifestReference: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let sourceFileName: String
  public let sourceNodeID: String
  public let sourceNodeName: String
  public let sourcePageName: String?
  public let sourceNodeType: String
  public let confidence: Double

  public init(
    id: String,
    title: String,
    summary: String,
    sourceFileName: String,
    sourceNodeID: String,
    sourceNodeName: String,
    sourcePageName: String?,
    sourceNodeType: String,
    confidence: Double
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.sourceFileName = sourceFileName
    self.sourceNodeID = sourceNodeID
    self.sourceNodeName = sourceNodeName
    self.sourcePageName = sourcePageName
    self.sourceNodeType = sourceNodeType
    self.confidence = confidence
  }
}
