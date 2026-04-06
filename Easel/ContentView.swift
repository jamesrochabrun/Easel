//
//  ContentView.swift
//  Easel
//
//  Created by James Rochabrun on 3/22/26.
//

import Canvas
import SwiftUI
import os

private let logger = Logger(subsystem: "com.easel", category: "ContentView")

struct ContentView: View {
  @State private var inspectState = ElementInspectState()
  @State private var terminalBridge = TerminalBridge()
  @State private var isLoading = false
  @State private var currentURL: URL?

  var body: some View {
    VSplitView {
      // Top: Web view or placeholder
      if let url = terminalBridge.localhostDetector.detectedURL {
        InspectableWebView(
          url: url,
          isFileURL: false,
          onLoadingChange: { isLoading = $0 },
          onURLChange: { currentURL = $0 },
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
          terminalBridge.sendPrompt(prompt)
        }
        .frame(minHeight: 200)
      } else {
        VStack(spacing: 12) {
          Spacer()
          Image(systemName: "globe")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text("Waiting for dev server...")
            .font(.headline)
            .foregroundStyle(.secondary)
          Text("Start a local server in the terminal below")
            .font(.caption)
            .foregroundStyle(.tertiary)
          Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color(nsColor: .windowBackgroundColor))
      }

      // Bottom: Terminal
      EaselTerminalView(
        projectPath: NSHomeDirectory(),
        bridge: terminalBridge
      )
      .frame(minHeight: 150)
    }
    .onChange(of: terminalBridge.localhostDetector.detectedURL) { oldURL, newURL in
      logger.notice("ContentView: detectedURL changed from \(oldURL?.absoluteString ?? "nil") → \(newURL?.absoluteString ?? "nil")")
    }
  }
}

#Preview {
  ContentView()
}
