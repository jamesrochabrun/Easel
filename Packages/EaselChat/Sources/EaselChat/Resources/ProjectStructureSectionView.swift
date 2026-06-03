//
//  ProjectStructureSectionView.swift
//  EaselChat
//

import SwiftUI

struct ProjectStructureSectionView: View {
  let section: ProjectStructureSection
  let selectedItem: ProjectResourcePanelItem?
  let onSelect: (ProjectResourcePanelItem) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(section.title.uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)

      VStack(spacing: 4) {
        ForEach(section.items) { item in
          ProjectStructureRow(
            item: item,
            isSelected: selectedItem?.id == ProjectResourcePanelItem.projectFile(item).id,
            onSelect: {
              onSelect(.projectFile(item))
            }
          )
        }
      }
    }
  }
}
