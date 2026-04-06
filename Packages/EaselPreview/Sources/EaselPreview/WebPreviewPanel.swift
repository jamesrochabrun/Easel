//
//  WebPreviewPanel.swift
//  EaselPreview
//

import Canvas
import EaselKit
import SwiftUI

public struct WebPreviewPanel: View {
  @State private var inspectState = ElementInspectState()
  let previewURLProvider: PreviewURLProviding
  let inspectorBridge: InspectorBridgeProtocol

  public init(previewURLProvider: PreviewURLProviding, inspectorBridge: InspectorBridgeProtocol) {
    self.previewURLProvider = previewURLProvider
    self.inspectorBridge = inspectorBridge
  }

  public var body: some View {
    Group {
      if let url = previewURLProvider.previewURL {
        InspectableWebView(
          url: url,
          isFileURL: false,
          onElementSelected: { element in
            inspectState.selectElement(element)
          },
          isInspectModeActive: $inspectState.isActive,
          selectedElementId: inspectState.selectedElement?.id
        )
        .webInspectorOverlay(
          state: inspectState,
          onSubmit: { element, instruction in
            let prompt = ElementInspectorPromptBuilder.buildPrompt(
              element: element,
              instruction: instruction
            )
            inspectorBridge.sendInspectorPrompt(prompt)
          },
          onContextSelection: { element in
            let prompt = ElementInspectorPromptBuilder.buildContextPrompt(
              element: element
            )
            inspectorBridge.sendContextPrompt(prompt)
          },
          onCropSubmit: { rect, elements, instruction in
            let prompt = ElementInspectorPromptBuilder.buildCropPrompt(
              cropRect: rect,
              elements: elements,
              instruction: instruction
            )
            inspectorBridge.sendCropPrompt(prompt)
          }
        )
      } else {
        placeholderView
      }
    }
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
