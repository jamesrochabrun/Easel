//
//  EaselDesignSystemPreset+Catalog.swift
//  EaselChat
//

import Foundation

extension EaselDesignSystemPreset {
  var catalog: EaselDesignSystemCatalog {
    switch self {
    case .airbnb:
      return EaselDesignSystemCatalog(
        name: displayName,
        summary: "Marketplace-style product UI with warm surfaces, approachable controls, and polished listing patterns.",
        generatedAt: nil,
        componentGroups: [
          EaselDesignSystemComponentGroup(
            id: "marketplace",
            title: "Marketplace",
            summary: "Browse, wishlist, detail, and reservation patterns",
            previewPath: nil,
            items: [
              EaselDesignSystemComponentItem(id: "listing-card", title: "Listing cards", summary: "Photography-first cards with heart, rating, price, and location metadata"),
              EaselDesignSystemComponentItem(id: "search-pill", title: "Search pills", summary: "Rounded search and filter affordances for discovery flows"),
            ]
          ),
          EaselDesignSystemComponentGroup(
            id: "badges-pills",
            title: "Badges & pills",
            summary: "Status badges and category pills",
            previewPath: nil,
            items: [
              EaselDesignSystemComponentItem(id: "status-badges", title: "Status badges", summary: "Guest favorite, rare find, and host status indicators"),
              EaselDesignSystemComponentItem(id: "category-pills", title: "Category pills", summary: "Cabins, beachfront, trending, and category filters"),
            ]
          ),
          EaselDesignSystemComponentGroup(
            id: "buttons",
            title: "Buttons",
            summary: "Primary, dark, outline, ghost, and circular navigation",
            previewPath: nil,
            items: []
          ),
        ]
      )
    case .apple:
      return EaselDesignSystemCatalog(
        name: displayName,
        summary: "Native-feeling Apple platform UI with clear hierarchy, restrained surfaces, and accessibility-first controls.",
        generatedAt: nil,
        componentGroups: [
          EaselDesignSystemComponentGroup(
            id: "controls",
            title: "Controls",
            summary: "Native controls, toolbar actions, menus, and segmented pickers",
            previewPath: nil,
            items: []
          ),
          EaselDesignSystemComponentGroup(
            id: "surfaces",
            title: "Surfaces",
            summary: "Windows, panels, sheets, sidebars, and material-backed surfaces",
            previewPath: nil,
            items: []
          ),
        ]
      )
    case .material:
      return EaselDesignSystemCatalog(
        name: displayName,
        summary: "Material-style product UI with explicit elevation, stateful components, rhythm, and accessible color contrast.",
        generatedAt: nil,
        componentGroups: [
          EaselDesignSystemComponentGroup(
            id: "elevation",
            title: "Elevation",
            summary: "Cards, sheets, menus, and surfaces with clear depth relationships",
            previewPath: nil,
            items: []
          ),
          EaselDesignSystemComponentGroup(
            id: "stateful-controls",
            title: "Stateful controls",
            summary: "Buttons, fields, tabs, and selections with hover, focus, pressed, and disabled states",
            previewPath: nil,
            items: []
          ),
        ]
      )
    case .none:
      return EaselDesignSystemCatalog(
        name: displayName,
        summary: "No reusable design system is selected for this project.",
        generatedAt: nil,
        componentGroups: []
      )
    }
  }
}
