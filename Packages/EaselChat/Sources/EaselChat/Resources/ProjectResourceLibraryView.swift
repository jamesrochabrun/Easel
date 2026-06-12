//
//  ProjectResourceLibraryView.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceLibraryView: View {
  let resources: [ProjectResource]
  let projectStructureSections: [ProjectStructureSection]
  let selectedItem: ProjectResourcePanelItem?
  let columns: [GridItem]
  let onSelect: (ProjectResourcePanelItem) -> Void
  let onDelete: (ProjectResourcePanelItem) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 22) {
        if !resources.isEmpty {
          ProjectResourceSectionHeader(title: "Design Files", count: resources.count)

          LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(resources) { resource in
              ProjectResourceCard(
                resource: resource,
                isSelected: selectedItem?.id == ProjectResourcePanelItem.resource(resource).id,
                onSelect: {
                  onSelect(.resource(resource))
                },
                onDelete: {
                  onDelete(.resource(resource))
                }
              )
            }
          }
        }

        if !projectStructureSections.isEmpty {
          ProjectResourceSectionHeader(title: "Project Structure", count: projectStructureFileCount)

          VStack(alignment: .leading, spacing: 14) {
            ForEach(projectStructureSections) { section in
              ProjectStructureSectionView(
                section: section,
                selectedItem: selectedItem,
                onSelect: onSelect,
                onDelete: onDelete
              )
            }
          }
        }
      }
      .padding(16)
    }
  }

  private var projectStructureFileCount: Int {
    projectStructureSections.reduce(0) { count, section in
      count + section.items.count
    }
  }
}
