//
//  ProjectResourceTextPreview.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceTextPreview: View {
  let text: String

  var body: some View {
    ScrollView([.horizontal, .vertical]) {
      Text(displayText)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(text.isEmpty ? .secondary : .primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial)
  }

  private var displayText: String {
    text.isEmpty ? "Empty file" : text
  }
}
