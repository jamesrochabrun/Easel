//
//  EaselDesignSystemStartingPoint.swift
//  EaselDesignSystems
//

import Foundation

public struct EaselDesignSystemStartingPoint: Equatable, Sendable {
  public let designSystem: EaselDesignSystemChoice
  public let catalogName: String
  public let groupID: String
  public let groupTitle: String
  public let itemID: String?
  public let itemTitle: String?
  public let summary: String
  public let previewPath: String?
  public let sourcePath: String?

  public var displayTitle: String {
    itemTitle ?? groupTitle
  }

  public var promptContext: String {
    var lines = [
      "--- Design System Starting Point ---",
      "Design system: \(designSystem.displayName)",
      "Catalog: \(catalogName)",
      "Component group: \(groupTitle) (\(groupID))",
      "Starting point: \(displayTitle)",
      "Summary: \(summary)",
    ]

    if let itemID {
      lines.append("Component item id: \(itemID)")
    }

    if let workingDirectory = designSystem.workingDirectory {
      lines.append("Design system folder: \(workingDirectory)")
    }

    if let previewPath {
      lines.append("Preview path: \(previewPath)")
    }

    if let sourcePath {
      lines.append("Source path: \(sourcePath)")
    }

    lines.append("Use this as a concrete starting point, then adapt it to the current project instead of copying it blindly.")
    return lines.joined(separator: "\n")
  }

  public init(
    designSystem: EaselDesignSystemChoice,
    catalogName: String,
    groupID: String,
    groupTitle: String,
    itemID: String?,
    itemTitle: String?,
    summary: String,
    previewPath: String?,
    sourcePath: String?
  ) {
    self.designSystem = designSystem
    self.catalogName = catalogName
    self.groupID = groupID
    self.groupTitle = groupTitle
    self.itemID = itemID
    self.itemTitle = itemTitle
    self.summary = summary
    self.previewPath = previewPath
    self.sourcePath = sourcePath
  }

  public static func group(
    designSystem: EaselDesignSystemChoice,
    catalog: EaselDesignSystemCatalog,
    group: EaselDesignSystemComponentGroup
  ) -> EaselDesignSystemStartingPoint {
    EaselDesignSystemStartingPoint(
      designSystem: designSystem,
      catalogName: catalog.name,
      groupID: group.id,
      groupTitle: group.title,
      itemID: nil,
      itemTitle: nil,
      summary: group.summary,
      previewPath: group.previewPath,
      sourcePath: group.sourcePath
    )
  }

  public static func item(
    designSystem: EaselDesignSystemChoice,
    catalog: EaselDesignSystemCatalog,
    group: EaselDesignSystemComponentGroup,
    item: EaselDesignSystemComponentItem
  ) -> EaselDesignSystemStartingPoint {
    EaselDesignSystemStartingPoint(
      designSystem: designSystem,
      catalogName: catalog.name,
      groupID: group.id,
      groupTitle: group.title,
      itemID: item.id,
      itemTitle: item.title,
      summary: item.summary,
      previewPath: item.previewPath ?? group.previewPath,
      sourcePath: item.sourcePath ?? group.sourcePath
    )
  }
}
