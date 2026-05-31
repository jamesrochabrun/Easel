//
//  ProjectResourcesEmptyState.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourcesEmptyState: View {
  let systemImage: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(.secondary)

      Text(title)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 340)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
