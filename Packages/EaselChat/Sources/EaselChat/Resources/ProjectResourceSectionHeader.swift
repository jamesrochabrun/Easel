//
//  ProjectResourceSectionHeader.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceSectionHeader: View {
  let title: String
  let count: Int

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)

      Text("\(count)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.thinMaterial, in: Capsule())

      Spacer()
    }
  }
}
