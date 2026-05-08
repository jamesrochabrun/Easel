import CCCustomPermissionServiceInterface
import SwiftUI
import AppKit
import Foundation

// MARK: - ApprovalToast

/// Compact toast-style approval UI that slides up from the bottom
public struct ApprovalToast: View {

  // MARK: Lifecycle

  public init(
    request: ApprovalRequest,
    showRiskData: Bool = true,
    queueCount: Int = 0,
    onApprove: @escaping () -> Void,
    onDeny: @escaping () -> Void,
    onDenyWithGuidance: @escaping (String) -> Void = { _ in },
    onCancel: @escaping () -> Void = { }
  ) {
    self.request = request
    self.showRiskData = showRiskData
    self.queueCount = queueCount
    self.onApprove = onApprove
    self.onDeny = onDeny
    self.onDenyWithGuidance = onDenyWithGuidance
    self.onCancel = onCancel
  }

  // MARK: Public

  public var body: some View {
    VStack(spacing: 0) {
      mainCompactView

      if showDetails {
        expandableDetailsView
      }
    }
    .background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(borderColor, lineWidth: 1)
    )
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        showDetails.toggle()
      }
    }
    .focusable()
    .focused($isFocused)
    .onAppear {
      isFocused = true
    }
  }

  // MARK: Internal

  let request: ApprovalRequest
  let showRiskData: Bool
  let queueCount: Int
  let onApprove: () -> Void
  let onDeny: () -> Void
  let onDenyWithGuidance: (String) -> Void
  let onCancel: () -> Void

  // MARK: Private

  @State private var showDetails = false
  @State private var showGuidanceInput = false
  @State private var denyGuidance = ""
  @FocusState private var isFocused: Bool
  @FocusState private var isGuidanceFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  private var isEditTool: Bool {
    ["Edit", "MultiEdit", "Write"].contains(request.toolName)
  }

  /// Extracts the most relevant parameter to display for this tool type
  private func extractRelevantParameter() -> (key: String, value: String)? {
    let parameterKey: String
    switch request.toolName.lowercased() {
    case "bash":
      parameterKey = "command"
    case "edit", "write", "read", "multiedit":
      parameterKey = "file_path"
    default:
      guard let firstKey = request.input.keys.sorted().first else { return nil }
      parameterKey = firstKey
    }

    guard let value = request.input[parameterKey] else {
      guard let firstKey = request.input.keys.sorted().first,
            let firstValue = request.input[firstKey] else {
        return nil
      }
      return (key: firstKey, value: firstValue.description)
    }

    return (key: parameterKey, value: value.description)
  }

  // MARK: - Theme Colors (matches EaselChatRuntimeStyle values)

  private var cardBackground: Color {
    colorScheme == .dark
      ? Color(nsColor: NSColor(srgbRed: 0.14, green: 0.14, blue: 0.14, alpha: 1))
      : Color(nsColor: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 1))
  }

  private var subtleBackground: Color {
    colorScheme == .dark
      ? Color(nsColor: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.11, alpha: 1))
      : Color(nsColor: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.98, alpha: 1))
  }

  private var borderColor: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.10)
      : Color.black.opacity(0.06)
  }

  private var secondaryText: Color {
    colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.46)
  }

  private var tertiaryText: Color {
    colorScheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.28)
  }

  // MARK: - Main Layout

  private var mainCompactView: some View {
    HStack(spacing: 8) {
      riskIndicator
      toolInfoSection
      Spacer(minLength: 8)
      actionButtonsSection
    }
    .padding(10)
  }

  private var riskIndicator: some View {
    Circle()
      .fill(riskColor)
      .frame(width: 8, height: 8)
  }

  private var toolInfoSection: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Text("Allow \(request.toolName)?")
          .font(.callout.bold())
          .foregroundStyle(.primary)

        if queueCount > 0 {
          Text("+\(queueCount) pending")
            .font(.caption2)
            .foregroundStyle(tertiaryText)
        }
      }

      if let parameter = extractRelevantParameter() {
        Text(parameter.value)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(secondaryText)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    }
  }

  private var actionButtonsSection: some View {
    HStack(spacing: 6) {
      Button(action: {
        if isEditTool {
          withAnimation(.easeInOut(duration: 0.2)) {
            showGuidanceInput = true
            showDetails = true
          }
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isGuidanceFocused = true
          }
        } else {
          onDeny()
        }
      }) {
        HStack(spacing: 3) {
          Text("Deny")
            .font(.caption)
          Text("esc")
            .font(.caption2)
            .foregroundStyle(tertiaryText)
        }
      }
      .buttonStyle(.plain)
      .foregroundStyle(secondaryText)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(subtleBackground, in: RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(borderColor, lineWidth: 1)
      )
      .keyboardShortcut(.escape, modifiers: [])

      Button(action: {
        onApprove()
      }) {
        HStack(spacing: 3) {
          Text("Allow")
            .font(.caption.bold())
          Text("\u{23CE}")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .tint(Color(red: 52 / 255, green: 211 / 255, blue: 128 / 255))
      .keyboardShortcut(.defaultAction)
    }
  }

  // MARK: - Expandable Details

  private var expandableDetailsView: some View {
    VStack(alignment: .leading, spacing: 6) {
      Rectangle()
        .fill(borderColor)
        .frame(height: 1)

      if let description = request.context?.description {
        Text(description)
          .font(.caption)
          .foregroundStyle(secondaryText)
      }

      if !request.input.isEmpty {
        parametersSection
      }

      if showGuidanceInput && isEditTool {
        guidanceInputSection
      }
    }
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
  }

  private var parametersSection: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("Parameters")
        .font(.caption.bold())
        .foregroundStyle(secondaryText)

      ForEach(Array(request.input.keys.prefix(3).sorted()), id: \.self) { key in
        HStack(spacing: 4) {
          Text("\(key):")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(tertiaryText)
          Text(request.input[key]?.description ?? "")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(secondaryText)
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }

      if request.input.count > 3 {
        Text("+ \(request.input.count - 3) more")
          .font(.caption2)
          .foregroundStyle(tertiaryText)
      }
    }
  }

  private var guidanceInputSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("What should be done instead?")
        .font(.caption.bold())
        .foregroundStyle(secondaryText)

      HStack(spacing: 6) {
        TextField("e.g., Use a different approach...", text: $denyGuidance)
          .textFieldStyle(.roundedBorder)
          .font(.caption)
          .focused($isGuidanceFocused)
          .onSubmit {
            let guidance = denyGuidance.isEmpty
              ? "User denied the request but provided no specific guidance"
              : denyGuidance
            onDenyWithGuidance(guidance)
          }

        Button("Cancel") {
          onCancel()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(secondaryText)

        Button("Send") {
          let guidance = denyGuidance.isEmpty
            ? "User denied the request but provided no specific guidance"
            : denyGuidance
          onDenyWithGuidance(guidance)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(Color(red: 52 / 255, green: 211 / 255, blue: 128 / 255))
      }
    }
  }

  private var riskColor: Color {
    switch request.context?.riskLevel {
    case .low: Color(red: 52 / 255, green: 211 / 255, blue: 128 / 255)
    case .medium: Color(red: 255 / 255, green: 158 / 255, blue: 64 / 255)
    case .high: Color(red: 255 / 255, green: 158 / 255, blue: 64 / 255)
    case .critical: Color(red: 242 / 255, green: 77 / 255, blue: 77 / 255)
    case .none: Color(red: 102 / 255, green: 166 / 255, blue: 255 / 255)
    }
  }
}

// MARK: - ToastContainer

/// Container for showing toast with animation
public struct ToastContainer: View {

  // MARK: Lifecycle

  public init(
    isPresented: Binding<Bool>,
    @ViewBuilder content: () -> some View
  ) {
    _isPresented = isPresented
    self.content = AnyView(content())
  }

  // MARK: Public

  public var body: some View {
    GeometryReader { _ in
      VStack {
        Spacer()

        if isPresented {
          content
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .transition(.asymmetric(
              insertion: .move(edge: .bottom).combined(with: .opacity),
              removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresented)
        }
      }
    }
    .allowsHitTesting(isPresented)
  }

  // MARK: Internal

  @Binding var isPresented: Bool

  let content: AnyView

}

// MARK: - Preview

#if DEBUG
struct ApprovalToast_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color(nsColor: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1))
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "LS",
            input: [
              "path": .string("/Users/test/Desktop"),
              "ignore": .array([.string("*.tmp")]),
            ],
            toolUseId: "ls-123",
            context: ApprovalContext(
              description: "List files and directories in the specified path",
              riskLevel: .low,
              isSensitive: false,
              affectedResources: ["/Users/test/Desktop"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onCancel: { }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Low Risk Toast")

    ZStack {
      Color(nsColor: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1))
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "Bash",
            input: [
              "command": .string("rm -rf /tmp/cache"),
              "timeout": .integer(30),
            ],
            toolUseId: "bash-456",
            context: ApprovalContext(
              description: "Execute shell command that may modify system files",
              riskLevel: .critical,
              isSensitive: true,
              affectedResources: ["/tmp/cache"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onCancel: { }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Critical Risk Toast")

    ZStack {
      Color(nsColor: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1))
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "Edit",
            input: [
              "file_path": .string("/Users/test/main.swift"),
              "old_string": .string("func test()"),
              "new_string": .string("func testNew()"),
            ],
            toolUseId: "edit-789",
            context: ApprovalContext(
              description: "Edit file to rename function",
              riskLevel: .medium,
              isSensitive: false,
              affectedResources: ["/Users/test/main.swift"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onDenyWithGuidance: { guidance in
            print("Guidance: \(guidance)")
          },
          onCancel: {
            print("Cancelled - Stream will be interrupted")
          }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Edit Tool with Deny & Guide")
  }
}
#endif
