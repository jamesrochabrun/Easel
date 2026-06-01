//
//  DesignSystemFileImportRow.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemFileImportRow: View {
  let title: String
  let buttonTitle: String
  let systemImage: String
  let selectedURLs: [URL]
  let onBrowse: () -> Void
  let onRemove: (URL) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 14) {
        Text(title)
          .font(.title3.weight(.semibold))
          .frame(width: 260, alignment: .leading)

        Button(action: onBrowse) {
          Label(buttonTitle, systemImage: systemImage)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }

      if !selectedURLs.isEmpty {
        DesignSystemSelectedURLList(urls: selectedURLs, onRemove: onRemove)
          .padding(.leading, 274)
      }
    }
  }
}
