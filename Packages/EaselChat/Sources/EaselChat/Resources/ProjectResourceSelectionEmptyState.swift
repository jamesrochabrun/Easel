//
//  ProjectResourceSelectionEmptyState.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceSelectionEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.viewfinder")
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No file selected")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
