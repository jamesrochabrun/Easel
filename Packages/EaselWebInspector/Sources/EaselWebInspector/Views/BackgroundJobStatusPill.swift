//
//  BackgroundJobStatusPill.swift
//  EaselWebInspector
//
//  Floating capsule surfacing one background tweaks job on the canvas:
//  progress + elapsed + Cancel while running, Applied · Undo on success,
//  conflict resolution actions on drift, Retry / Send-to-chat on failure.
//

import EaselKit
import SwiftUI

// MARK: - BackgroundJobStatusPill

public struct BackgroundJobStatusPill: View {
  let job: BackgroundAgentJobSnapshot
  let onCancel: () -> Void
  let onResolveConflict: (BackgroundAgentConflictResolution) -> Void
  let postApplyDriftedFiles: () async -> [String]
  let onUndo: (_ force: Bool) -> Void
  let onRetry: () -> Void
  let onSendToChat: () -> Void
  let onDismiss: () -> Void

  @State private var isConfirmingUndo = false
  @State private var undoDriftedFiles: [String] = []

  public init(
    job: BackgroundAgentJobSnapshot,
    onCancel: @escaping () -> Void,
    onResolveConflict: @escaping (BackgroundAgentConflictResolution) -> Void,
    postApplyDriftedFiles: @escaping () async -> [String],
    onUndo: @escaping (_ force: Bool) -> Void,
    onRetry: @escaping () -> Void,
    onSendToChat: @escaping () -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.job = job
    self.onCancel = onCancel
    self.onResolveConflict = onResolveConflict
    self.postApplyDriftedFiles = postApplyDriftedFiles
    self.onUndo = onUndo
    self.onRetry = onRetry
    self.onSendToChat = onSendToChat
    self.onDismiss = onDismiss
  }

  public var body: some View {
    HStack(spacing: 10) {
      statusContent
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial, in: Capsule())
    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    .contentShape(Capsule())
    .confirmationDialog(
      "Undo tweaks?",
      isPresented: $isConfirmingUndo,
      titleVisibility: .visible
    ) {
      Button("Undo anyway", role: .destructive) { onUndo(true) }
      Button("Keep changes", role: .cancel) {}
    } message: {
      Text(
        "\(fileList(undoDriftedFiles)) changed after the tweaks were applied. "
          + "Undoing will overwrite those edits."
      )
    }
  }

  // MARK: - Status content

  @ViewBuilder
  private var statusContent: some View {
    switch job.status {
    case .queued, .preparingWorkspace:
      workingContent(text: "Tweaks queued…", showsElapsed: false)

    case .generating:
      workingContent(
        text: job.activityDescription ?? "Generating tweaks for \(job.request.displayFileName)…",
        showsElapsed: true
      )

    case .validating:
      workingContent(text: "Checking generated changes…", showsElapsed: true)

    case .waitingToApply:
      workingContent(text: "Ready — waiting for chat to finish…", showsElapsed: false)

    case .applying:
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        statusText("Applying tweaks…")
      }
      .accessibilityElement(children: .combine)

    case .applied:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 11))
        .foregroundStyle(.green)
      statusText("Tweaks applied")
      Button("Undo", action: requestUndo)
        .controlSize(.small)
        .help("Restore the files to their pre-tweaks content")
      dismissButton

    case .conflict(let driftedFiles):
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 11))
        .foregroundStyle(.orange)
      statusText("\(fileList(driftedFiles)) changed while generating")
      Button("Regenerate") { onResolveConflict(.regenerateOnLatest) }
        .controlSize(.small)
        .help("Run the tweaks again on the latest file content")
      Button("Apply anyway") { onResolveConflict(.applyAnyway) }
        .controlSize(.small)
        .help("Overwrite the newer edits with the generated tweaks (Undo restores them)")
      Button("Discard", role: .destructive) { onResolveConflict(.discard) }
        .controlSize(.small)
        .help("Throw the generated tweaks away")

    case .failed(let failure):
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 11))
        .foregroundStyle(.orange)
      statusText(failure.message)
      Button("Retry", action: onRetry)
        .controlSize(.small)
        .help("Run the tweaks again")
      Button("Send to chat", action: onSendToChat)
        .controlSize(.small)
        .help("Send this request to the chat agent instead")
      dismissButton

    case .cancelled, .undone:
      EmptyView()
    }
  }

  private func workingContent(text: String, showsElapsed: Bool) -> some View {
    HStack(spacing: 8) {
      ProgressView().controlSize(.small)
      statusText(text)
      if showsElapsed, let startedAt = job.startedAt {
        elapsedText(since: startedAt)
      }
      Button("Cancel", action: onCancel)
        .controlSize(.small)
        .help("Cancel tweaks generation")
    }
    .accessibilityElement(children: .combine)
  }

  private func statusText(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .truncationMode(.middle)
      .frame(maxWidth: 320, alignment: .leading)
  }

  private func elapsedText(since startedAt: Date) -> some View {
    TimelineView(.periodic(from: startedAt, by: 1)) { context in
      Text(Self.formatElapsed(context.date.timeIntervalSince(startedAt)))
        .font(.system(size: 11).monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }

  private var dismissButton: some View {
    Button(action: onDismiss) {
      Image(systemName: "xmark")
        .font(.system(size: 9, weight: .bold))
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .help("Dismiss")
    .accessibilityLabel("Dismiss")
  }

  // MARK: - Helpers

  private func requestUndo() {
    Task {
      let drifted = await postApplyDriftedFiles()
      if drifted.isEmpty {
        onUndo(false)
      } else {
        undoDriftedFiles = drifted
        isConfirmingUndo = true
      }
    }
  }

  private func fileList(_ relativePaths: [String]) -> String {
    let names = relativePaths.map { ($0 as NSString).lastPathComponent }
    guard let first = names.first else { return "A file" }
    if names.count == 1 { return first }
    return "\(first) and \(names.count - 1) more"
  }

  static func formatElapsed(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
