import SwiftUI

struct TweakGenerationBanner: View {
  static let message = "Tweaks are being generated. This can take a few minutes."
  let startedAt: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label {
        Text(Self.message)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        ProgressView()
          .controlSize(.small)
          .accessibilityHidden(true)
      }

      TimelineView(.periodic(from: startedAt, by: 1)) { context in
        Text(Self.elapsedTime(from: startedAt, to: context.date))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityLabel("Elapsed time")
          .accessibilityValue(Self.elapsedTime(from: startedAt, to: context.date))
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    .accessibilityElement(children: .combine)
  }

  static func elapsedTime(from startDate: Date, to currentDate: Date) -> String {
    let elapsedSeconds = max(0, Int(currentDate.timeIntervalSince(startDate)))
    let hours = elapsedSeconds / 3_600
    let minutes = (elapsedSeconds % 3_600) / 60
    let seconds = elapsedSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
  }
}
