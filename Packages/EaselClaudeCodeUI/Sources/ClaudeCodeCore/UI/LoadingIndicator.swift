//
//  LoadingIndicator.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/29/2025.
//

import SwiftUI

struct LoadingIndicator: View {
  let startTime: Date
  let inputTokens: Int
  let outputTokens: Int
  let costUSD: Double
  let showPrice: Bool
  let showTokenCount: Bool
  let activityText: String
  
  @State private var elapsedTime: TimeInterval = 0
  @State private var dots = ""
  @Environment(\.colorScheme) private var colorScheme
  
  private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
  private let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
  
  init(
    startTime: Date,
    inputTokens: Int = 0,
    outputTokens: Int = 0,
    costUSD: Double = 0.0,
    showPrice: Bool? = nil,
    showTokenCount: Bool = true,
    activityText: String = "Easel is working"
  ) {
    self.startTime = startTime
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.costUSD = costUSD
    self.showTokenCount = showTokenCount
    self.activityText = activityText
    
    // Show price only in debug builds by default
    #if DEBUG
    self.showPrice = showPrice ?? true
    #else
    self.showPrice = showPrice ?? false
    #endif
  }
  
  private var totalTokens: Int {
    inputTokens + outputTokens
  }
  
  private var formattedTime: String {
    String(format: "%.0fs", elapsedTime)
  }
  
  private var hasTokenData: Bool {
    inputTokens > 0 || outputTokens > 0
  }
  
  private var metadataText: String {
    var values = [formattedTime]
    
    if showTokenCount && hasTokenData {
      values.append("\(totalTokens) tokens")
    }
    
    if showPrice && costUSD > 0 {
      values.append("$\(String(format: "%.4f", costUSD))")
    }

    values.append("esc to interrupt")
    return values.joined(separator: " - ")
  }

  private var statusText: String {
    "\(activityText)\(dots)"
  }
  
  var body: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
        .tint(EaselChatRuntimeStyle.running)
        .accessibilityHidden(true)

      Text(statusText)
        .font(.callout.italic())
        .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))

      Text(metadataText)
        .font(.caption)
        .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))

      Spacer(minLength: 0)
    }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: EaselChatRuntimeStyle.maxContentWidth, alignment: .leading)
      .background(EaselChatRuntimeStyle.appBackground(for: colorScheme))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(activityText). \(metadataText)")
      .onReceive(timer) { _ in
        elapsedTime = Date().timeIntervalSince(startTime)
      }
      .onReceive(dotsTimer) { _ in
        dots = dots.count < 3 ? dots + "." : ""
      }
  }
}

#Preview("Loading Indicator") {
  VStack(spacing: 20) {
    // Without token data
    LoadingIndicator(
      startTime: Date()
    )
    
    // With token data but no price
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-5),
      inputTokens: 200,
      outputTokens: 29
    )
    
    // With token data and price (debug mode)
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-15.7),
      inputTokens: 1000,
      outputTokens: 850,
      costUSD: 0.0234
    )
    
    // Force hide price even in debug
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-10),
      inputTokens: 500,
      outputTokens: 400,
      costUSD: 0.0150,
      showPrice: false
    )
    
    // With token count hidden
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-8),
      inputTokens: 750,
      outputTokens: 600,
      costUSD: 0.0180,
      showTokenCount: false,
      activityText: "Checking tests"
    )
  }
  .padding()
  .frame(width: 600)
}
