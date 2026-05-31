//
//  ProjectResourceErrorBanner.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceErrorBanner: View {
  let message: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)

      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color.red.opacity(0.08))
  }
}
