//
//  WebPreviewPanel.swift
//  Easel
//

import Canvas
import SwiftUI

struct WebPreviewPanel: View {
  @State private var inspectState = ElementInspectState()
  @Binding var previewURL: URL?

  var body: some View {
    Group {
      if let url = previewURL {
        InspectableWebView(
          url: url,
          isFileURL: false,
          onElementSelected: { element in
            inspectState.selectElement(element)
          },
          isInspectModeActive: $inspectState.isActive,
          selectedElementId: inspectState.selectedElement?.id
        )
        .webInspectorOverlay(state: inspectState) { element, instruction in
          let prompt = ElementInspectorPromptBuilder.buildPrompt(
            element: element,
            instruction: instruction
          )
          // TODO: Bridge prompt to chat panel
          print(prompt)
        }
      } else {
        placeholderView
      }
    }
    .background(GlassBackgroundView(material: .sidebar))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var placeholderView: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "globe")
        .font(.system(size: 36, weight: .thin))
        .foregroundStyle(.tertiary)

      Text("Preview")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.secondary)

      Text("Web preview will appear here")
        .font(.system(size: 13))
        .foregroundStyle(.tertiary)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
