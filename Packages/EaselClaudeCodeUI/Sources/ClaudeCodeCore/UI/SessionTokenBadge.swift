//
//  SessionTokenBadge.swift
//  ClaudeCodeUI
//

import SwiftUI

struct SessionTokenBadge: View {
  let summary: SessionUsageSummary

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Label("Session \(summary.formattedTotalTokens)", systemImage: "number")
      .labelStyle(.titleAndIcon)
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))
      .lineLimit(1)
      .help("Exact provider-reported API usage for this session, including hidden instructions, tools, context, and visible messages: \(summary.formattedBreakdown)")
      .accessibilityLabel("Session API token usage \(summary.formattedBreakdown)")
  }
}
