//
//  DesignSystemCatalogGroupView.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

struct DesignSystemCatalogGroupView: View {
  let designSystem: EaselDesignSystemChoice
  let catalog: EaselDesignSystemCatalog
  let group: EaselDesignSystemComponentGroup
  let previewURL: URL?
  let onUseStartingPoint: (EaselDesignSystemStartingPoint) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 14) {
        DesignSystemComponentPreviewView(
          title: group.title,
          summary: group.summary,
          previewURL: previewURL
        )

        if group.items.isEmpty {
          Text(group.summary)
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        } else {
          ForEach(group.items) { item in
            DesignSystemCatalogItemRow(
              item: item,
              onUseStartingPoint: {
                onUseStartingPoint(.item(
                  designSystem: designSystem,
                  catalog: catalog,
                  group: group,
                  item: item
                ))
              }
            )
          }
        }
      }
      .padding(.leading, 42)
      .padding(.trailing, 18)
      .padding(.bottom, 18)
    } label: {
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 5) {
          Text(group.title)
            .font(.title3.weight(.semibold))
          Text(group.summary)
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Button("Use as starting point") {
          onUseStartingPoint(.group(
            designSystem: designSystem,
            catalog: catalog,
            group: group
          ))
        }
        .buttonStyle(.bordered)
      }
      .padding(.vertical, 18)
    }
    .padding(.horizontal, 22)
  }
}
