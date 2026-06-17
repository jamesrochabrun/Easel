//
//  CanvasProjectTokenBadge.swift
//  Easel
//

import ClaudeCodeCore
import EaselKit
import SwiftUI

struct CanvasProjectTokenBadge: View {
  let summary: SessionUsageSummary

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Label("Project \(summary.formattedTotalTokens)", systemImage: "number")
      .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .lineLimit(1)
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(
        EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
      .help("Exact provider-reported API usage across sessions in this project, including hidden instructions, tools, context, and visible messages: \(summary.formattedBreakdown)")
      .accessibilityLabel("Project API token usage \(summary.formattedBreakdown)")
  }
}
