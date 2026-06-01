//
//  PermissionModeIndicator.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025.
//

import SwiftUI
import ClaudeCodeSDK

// MARK: - Extensions for ClaudeCodeSDK.PermissionMode

extension ClaudeCodeSDK.PermissionMode {
  
  /// Human-readable display name for the mode
  public var displayName: String {
    switch self {
    case .default:
      return "default"
    case .plan:
      return "plan"
    case .acceptEdits:
      return "accept edits"
    case .bypassPermissions:
      return "bypass"
    }
  }
  
  /// Short description of what the mode does
  public var description: String {
    switch self {
    case .default:
      return "Normal permission checks"
    case .plan:
      return "Plan before execution"
    case .acceptEdits:
      return "Auto-accept file edits"
    case .bypassPermissions:
      return "No permission prompts"
    }
  }
  
  /// Icon name for the mode
  public var iconName: String {
    switch self {
    case .default:
      return "shield"
    case .plan:
      return "doc.plaintext"
    case .acceptEdits:
      return "forward.fill"
    case .bypassPermissions:
      return "shield.slash"
    }
  }

  /// Returns the next mode in the cycle for keyboard shortcut toggling
  public var nextMode: ClaudeCodeSDK.PermissionMode {
    let allCases: [ClaudeCodeSDK.PermissionMode] = [.default, .plan, .acceptEdits, .bypassPermissions]
    guard let currentIndex = allCases.firstIndex(of: self) else { return .default }
    let nextIndex = (currentIndex + 1) % allCases.count
    return allCases[nextIndex]
  }
}

/// A view that displays the current permission mode
public struct PermissionModeIndicator: View {
  let mode: ClaudeCodeSDK.PermissionMode
  let isCompact: Bool
  @Environment(\.colorScheme) private var colorScheme
  
  public init(mode: ClaudeCodeSDK.PermissionMode, isCompact: Bool = false) {
    self.mode = mode
    self.isCompact = isCompact
  }
  
  public var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(modeColor)
        .frame(width: 5, height: 5)
      
      if !isCompact {
        Text(mode.displayName)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
      }
    }
    .padding(.horizontal, isCompact ? 5 : 7)
    .padding(.vertical, 3)
    .background(EaselChatRuntimeStyle.panelBackground(for: colorScheme), in: Capsule())
    .overlay {
      Capsule()
        .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
    }
    .help("\(mode.description). Shift+Tab to cycle.")
  }
  
  private var modeColor: Color {
    switch mode {
    case .default:
      return EaselChatRuntimeStyle.tertiaryText(for: colorScheme)
    case .plan:
      return EaselChatRuntimeStyle.running
    case .acceptEdits:
      return EaselChatRuntimeStyle.completedForeground(for: colorScheme)
    case .bypassPermissions:
      return EaselChatRuntimeStyle.denied
    }
  }
}

/// A button that shows the current permission mode and allows cycling through modes
public struct PermissionModeButton: View {
  @Binding var mode: ClaudeCodeSDK.PermissionMode
  
  public init(
    mode: Binding<ClaudeCodeSDK.PermissionMode>)
  {
    _mode = mode
  }
  
  public var body: some View {
    Button(action: toggleMode) {
      PermissionModeIndicator(mode: mode)
    }
    .buttonStyle(.plain)
    .help("Permission Mode: \(mode.description)\nShift+Tab to cycle modes")
  }
  
  private func toggleMode() {
    let newMode = mode.nextMode
    mode = newMode
  }
}

#Preview {
  VStack(spacing: 20) {
    let allModes: [ClaudeCodeSDK.PermissionMode] = [.default, .plan, .acceptEdits, .bypassPermissions]
    ForEach(allModes, id: \.self) { mode in
      HStack {
        PermissionModeIndicator(mode: mode)
        PermissionModeIndicator(mode: mode, isCompact: true)
      }
    }
    
    Divider()
    
    PermissionModeButton(mode: .constant(.default))
  }
  .padding()
}
